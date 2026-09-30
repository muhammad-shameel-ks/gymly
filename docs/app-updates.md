# In-app updates

How the app updates itself from the GitHub Releases the pipeline publishes. The
release side lives in `docs/ci-cd.md`; this is the app side, and the contract
between the two.

## The path

Profile → **App** → `Check for update` → `Download update` → `Install update`.

1. **Check** — one request to
   `https://api.github.com/repos/muhammad-shameel-ks/gymly/releases/latest`
   (`Accept: application/vnd.github+json`,
   `X-GitHub-Api-Version: 2022-11-28`). The repository is public, so no token is
   involved; the app spends one of the 60 requests/hour an unauthenticated
   caller gets per IP, and only when the owner taps.
2. **Compare** — `tag_name` (`vX.Y.Z`) against the installed version
   (`package_info_plus` reads the built `pubspec.yaml`). Only `X.Y.Z` counts: a
   release build takes its build number from the CI run number, so it orders
   nothing.
3. **Pick the file** — the asset for the device's first `supportedAbis` entry,
   among the three the pipeline publishes. The AAB is not installable, and a
   `-debugsigned` APK (a run without the upload key) is refused by Android
   anyway, so neither is ever offered.
4. **Download** — streamed to
   `getTemporaryDirectory()/updates/gymly-<version>-<abi>.apk`, with progress.
   The byte count has to match the asset's size: a truncated file is deleted
   rather than handed to the installer.
5. **Install** — the file is opened with the system installer
   (`application/vnd.android.package-archive`) through `open_filex`'s
   FileProvider, so no `file://` URI is exposed. `REQUEST_INSTALL_PACKAGES` is
   declared in `src/main/AndroidManifest.xml` and asserted on the built release
   APK in CI; the owner grants "install unknown apps" for Gymly the first time.

## What the app deliberately does not do

- **No signature or digest check in Dart.** Android's installer is the trust
  anchor: it refuses an APK whose signature differs from the installed app, so
  the upload key is what makes an update trustworthy. A check in Dart would be a
  second, weaker copy of that decision.
- **No automatic or background check.** A network call the owner did not ask for
  is not worth a state they then have to reason about.
- **No iOS path.** `docs/ci-cd.md` § Not covered: iOS needs a macOS runner and
  an Apple certificate, and App Store updates do not come from GitHub Releases.
  The card is Android-only.

## The two ways this fails in the field

- **"App not installed"** — the installed app was not signed with the upload key
  (a `flutter run` debug build, or a locally built release). Android refuses the
  update; installing a release APK by hand over a debug build ends the same way.
  Nothing in the app can fix it, and nothing should pretend to.
- **Nothing offered on a phone the pipeline does not build for** — an x86-only
  device has no matching APK, so the card says the version has no file for this
  phone rather than claiming the app is up to date.

## Verifying a published release is installable

```bash
gh release download vX.Y.Z -p 'gymly-vX.Y.Z-arm64-v8a.apk' -D /tmp/release
"$ANDROID_HOME"/build-tools/*/aapt2 dump badging /tmp/release/*.apk | grep uses-permission
"$ANDROID_HOME"/build-tools/*/apksigner verify --print-certs /tmp/release/*.apk
```

Both permissions (`INTERNET`, `REQUEST_INSTALL_PACKAGES`) and the upload-key
certificate have to be there — the first two decide whether the app can work at
all, the third decides whether an update can replace what is installed.
