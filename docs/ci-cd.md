# CI/CD

Everything the repo automates: what runs when, what it caches, how a release is
cut, and how the Android build is signed. The Flutter project lives in `app/`,
so every workflow runs with `working-directory: app`.

## Workflows

| File | Trigger | What it does |
|---|---|---|
| `.github/workflows/ci.yml` | PR to `main`, push to `main`, manual | `flutter pub get`, `flutter analyze`, `flutter test`, and in parallel the same release-mode split APKs the release builds — uploaded as artifacts and signature-checked. Docs-only changes are skipped (`paths-ignore`). |
| `.github/workflows/release.yml` | push to `main`, push of a `v*` tag, manual (with a tag) | On `main`: release-please opens/updates the release PR. When a release is cut — or a tag is pushed by hand — the `android` job builds the signed AAB + per-ABI APKs and attaches them to the GitHub Release. |
| `.github/dependabot.yml` | weekly / monthly | Dependency PRs for pub, Gradle and the workflow actions. |

Both workflows share a `concurrency` group per ref: a superseded CI run is
cancelled, a release run never is.

### Why release-please and the build share one workflow

A tag created with the default `GITHUB_TOKEN` does **not** trigger another
workflow run. If release-please published in one workflow and a tag-triggered
workflow built the APKs, the artifacts would never be produced. So
`release.yml` runs release-please first and gates the build job on its
`release_created` output in the same run. A hand-pushed `v*` tag still works, and
`workflow_dispatch` with a tag rebuilds and re-attaches artifacts for an
existing release.

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

1. Merge work to `main` with [conventional commit](https://www.conventionalcommits.org)
   messages: `fix:` bumps the patch, `feat:` the minor, `feat!:` / `BREAKING CHANGE:`
   the major. `docs:`/`ci:`/`chore:` do not appear in the changelog.
2. release-please opens (and keeps updating) a `chore(release): X.Y.Z` PR that
   bumps `app/pubspec.yaml` and writes `app/CHANGELOG.md`.
3. Merge that PR. release-please tags `vX.Y.Z` and publishes the GitHub Release;
   the same run builds and attaches `gymly-vX.Y.Z-<abi>.apk` (arm64-v8a,
   armeabi-v7a, x86_64) and `gymly-vX.Y.Z.aab`.
4. Manual escape hatches: push a `vX.Y.Z` tag yourself, or run the Release
   workflow with `tag: vX.Y.Z` to rebuild and re-attach.

The first release (`v1.0.0`) was cut by hand before release-please existed;
`.release-please-manifest.json` records `1.0.0` so the next release bumps from
there.

`separate-pull-requests` must stay `true`, even though there is only one package.
With it `false`, release-please runs its merge plugin, which names the release
branch `release-please--branches--main` — no component — while the dart strategy's
branch component is `gymly`. The tag step compares the two, refuses the merged PR
(`PR component: undefined does not match configured component: gymly`), and the
release is never tagged; the following run then aborts with *untagged, merged
release PRs outstanding*. Recovering means tagging by hand and relabelling the PR
(`autorelease: pending` → `autorelease: tagged`).

## Not covered

- **iOS**: needs macOS runners and an Apple certificate/provisioning profile.
- **Store upload**: the AAB is attached to the GitHub Release; uploading to Play
  is a manual step (or a future job with a Play service account).
- **Supabase**: migrations and Edge Functions are applied out of band.
