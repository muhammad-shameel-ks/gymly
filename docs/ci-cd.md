# CI/CD

Everything the repo automates: what runs when, what it caches, how a release is
cut, and how the Android build is signed. The Flutter project lives in `app/`,
so every workflow runs with `working-directory: app`.

## Workflows

| File | Trigger | What it does |
|---|---|---|
| `.github/workflows/ci.yml` | PR to `main`, push to `main`, manual | `flutter pub get`, `flutter analyze`, `flutter test`, and in parallel the same release-mode split APKs the release builds — uploaded as artifacts and signature-checked. Docs-only changes are skipped (`paths-ignore`). |
| `.github/workflows/release.yml` | push to `main`, push of a `v*` tag, manual (with a tag) | On `main`: release-please opens/updates the release PR, `publish` merges it, release-please tags and publishes, and `android` builds the signed AAB + per-ABI APKs and attaches them. A hand-pushed `v*` tag or a `workflow_dispatch` only builds and attaches. |
| `.github/dependabot.yml` | weekly / monthly | Dependency PRs for pub, Gradle and the workflow actions. |
| `.github/workflows/opencode.yml` | issue opened or labelled | Runs the OpenCode agent on an issue that carries `ready-for-agent`; it implements the issue and opens a PR. See [Agent on issues](#agent-on-issues). |

CI and Release share a `concurrency` group per ref: a superseded CI run is
cancelled, a release run never is — a second push to `main` queues behind the
release in flight instead of racing it. The agent workflow groups per issue
instead, so one issue never runs twice at once.

### Branch model

`main` is the release branch: it always holds the last released state, and every
push that carries a bump-worthy commit is released automatically.

| Branch | Cut from | Merges into | Purpose |
|---|---|---|---|
| `feat/<slug>` | `main` | `main` | new behaviour, minor bump |
| `fix/<slug>` | `main` | `main` | defect, patch bump |
| `hotfix/<slug>` | `main` | `main` | urgent defect: same path as `fix/`, cut from the released `main` so it cannot carry unreleased work |

Short-lived by design: one branch, one PR, deleted on merge. There is no
integration branch — CI on the PR (analysis, tests, a release-mode APK build and
the INTERNET assertion on that APK) is the gate, and `main` only ever receives
PRs.

### Agent on issues

`.github/workflows/opencode.yml` runs the OpenCode agent when an issue carries
the `ready-for-agent` label — opened with it, or labelled later. There is no
comment command to type. The label *is* the trigger because this repository is
public: anyone can open an issue, but only someone with write access can label
one, so a stranger cannot start a run or feed the agent an injected prompt.

The agent reads `AGENTS.md`, implements the issue on a branch, runs
`flutter analyze` and `flutter test`, and opens a pull request with a
conventional-commit title. It is told never to push to `main` and never to
merge — merging `main` publishes a release (above) — so its output always
arrives as a reviewable PR, and an issue it cannot act on gets a comment
instead of a PR. Runs are serialized per issue and capped at 30 minutes;
`share: false` keeps the session transcript private.

Setup — the GitHub App install and the `OPENCODE_API_KEY` secret — is
`scripts/setup-opencode-agent.sh`. Both must exist before the first run: without
the app the OIDC token exchange fails, without the secret the agent has no
credentials.

### Why release-please, the merge and the build share one workflow

A tag or merge made with the default `GITHUB_TOKEN` does **not** trigger another
workflow run. If release-please opened the release PR in one workflow and the
APKs were built by a tag-triggered workflow, nothing would ever be published.
So one run does all three steps: `release-please` opens the PR, `publish` merges
it (`gh pr merge`, retrying while GitHub computes mergeability) and runs
release-please again with `skip-github-pull-request: true` to cut the tag, and
`android` is gated on the tag that step verified. A hand-pushed `v*` tag still
works, and `workflow_dispatch` with a tag rebuilds and re-attaches artifacts for
an existing release.

## Caching

Nothing is cached by hand:

- `subosito/flutter-action@v2` with `cache: true` — the Flutter SDK download and
  the pub cache, keyed on `pubspec.lock`.
- `gradle/actions/setup-gradle@v6` — the Gradle dependency cache, the wrapper
  distribution and the build cache, with the build scan.
- `app/android/gradle.properties` keeps the daemon heap at 4 GB
  (`-Xmx4G -XX:MaxMetaspaceSize=2G`), sized for a 7 GB GitHub runner rather than
  a 16 GB laptop; a bigger heap only makes CI swap.

Build flags used everywhere: `--split-per-abi` (one APK per ABI, ~3× smaller
downloads), `--obfuscate --split-debug-info=build/symbols` (Dart-level, keeps the
symbol files as a workflow artifact for de-minifying crash reports), and
`--build-number=${{ github.run_number }}` so every CI artifact has a monotonically
increasing Android `versionCode` — Play rejects an upload that reuses one.

R8 (`isMinifyEnabled` / `isShrinkResources`) is deliberately **off** for now:
it needs a device pass to prove no reflection is stripped, so it is a v1.1 item
with the device check attached, not a blind switch in a release pipeline.

## Signing

The release build is signed with the **upload key** when
`app/android/key.properties` exists, and debug-signed otherwise (so a bare
checkout still builds; artifact names carry `-debugsigned` in that case).

The upload key lives outside the repo: `~/.gymly-release/gymly-upload.jks`
(alias `gymly`, JKS, valid to 2054) with its passwords in
`~/.gymly-release/credentials.txt`. **Back both up** — an Android app can only be
updated with the same key, so losing it means a new app listing on Play:
`~/.gymly-release/gymly-upload.jks` and `credentials.txt`, plus the GitHub
secrets below.

Repository secrets the workflows read (`Settings → Secrets and variables →
Actions`):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 ~/.gymly-release/gymly-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | `gymly` |
| `ANDROID_KEY_PASSWORD` | the key password |

Without them CI still passes and still produces APKs — they are debug-signed.

## Cutting a release

Releasing is a side effect of merging to `main`; there is no button.

1. Open a PR to `main` from a `feat/`, `fix/` or `hotfix/` branch with a
   [conventional commit](https://www.conventionalcommits.org) message: `fix:`
   bumps the patch, `feat:` the minor, `feat!:` / `BREAKING CHANGE:` the major.
   `docs:`/`ci:`/`chore:`/`build:` do not appear in the changelog and do not bump
   — a push carrying only those opens no release PR and the pipeline stops after
   the `release-please` job.
2. Merge the PR. release-please opens (and keeps updating) a `chore(release): X.Y.Z`
   PR that bumps `app/pubspec.yaml` and writes `app/CHANGELOG.md`; `publish`
   merges it and tags `vX.Y.Z`; `android` attaches `gymly-vX.Y.Z-<abi>.apk`
   (arm64-v8a, armeabi-v7a, x86_64) and `gymly-vX.Y.Z.aab` to the release.
   All three jobs run in the same workflow run, ~12 minutes end to end.
3. Manual escape hatches: push a `vX.Y.Z` tag yourself, or run the Release
   workflow with `tag: vX.Y.Z` to rebuild and re-attach.

The release PR is merged without waiting for its own CI run: it only bumps the
version, the changelog and the manifest, and the artifact job builds from the
tagged commit anyway. That CI run is a redundant gate, and it is left visible
rather than suppressed, because `paths-ignore` cannot tell a release PR apart
from a dependency PR that edits `app/pubspec.yaml`.

The first release (`v1.0.0`) was cut by hand before release-please existed;
`.release-please-manifest.json` records the last released version so the next
release bumps from there.

`separate-pull-requests` must stay `true`, even though there is only one package.
With it `false`, release-please runs its merge plugin, which names the release
branch `release-please--branches--main` — no component — while the dart strategy's
branch component is `gymly`. The tag step compares the two, refuses the merged PR
(`PR component: undefined does not match configured component: gymly`), and the
release is never tagged; the following run then aborts with *untagged, merged
release PRs outstanding*. Recovering means tagging by hand and relabelling the PR
(`autorelease: pending` → `autorelease: tagged`).

## Android release gotchas

`app/android/app/src/main/AndroidManifest.xml` is the only manifest a release
build sees. The Flutter template declares `INTERNET` in `src/debug` and
`src/profile` for the tool (hot reload, breakpoints), and a release APK inherits
`src/main` alone — so a release build without that line installs, launches, and
then fails every Supabase call with `ClientException … Failed host lookup`. That
is how `v1.0.0` shipped; `v1.0.1` fixed it. No Dart test can see this class of
bug, so CI asserts the permission on the **built release APK** (`Network
permission in the release APK` in `ci.yml`), and a released artifact can be
checked by hand the same way:

```bash
gh release download vX.Y.Z -p 'gymly-vX.Y.Z-arm64-v8a.apk' -D /tmp/release
"$ANDROID_HOME"/build-tools/*/aapt2 dump badging /tmp/release/*.apk | grep uses-permission
```

Anything that is only true of a release build (manifest merging, R8, the
signing config, `versionCode`/`versionName`) belongs in that job, on the
artifact, not in a unit test.

## Not covered

- **iOS**: needs macOS runners and an Apple certificate/provisioning profile.
- **Store upload**: the AAB is attached to the GitHub Release; uploading to Play
  is a manual step (or a future job with a Play service account).
- **Supabase**: migrations and Edge Functions are applied out of band.
