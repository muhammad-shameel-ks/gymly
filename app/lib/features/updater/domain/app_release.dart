/// A published release, and the one APK in it this device can install.
///
/// The shape is the release pipeline's contract (`docs/ci-cd.md`, and the
/// `Name the artifacts` step in `release.yml`): every release carries
/// `gymly-<tag>-<abi>.apk` for arm64-v8a, armeabi-v7a and x86_64, plus the AAB.
/// Two asset classes are uninstallable on purpose and are never offered:
///
/// - the AAB, which is a Play upload and not something the system installer
///   accepts, and
/// - `-debugsigned` APKs, built on a run without the upload key: Android
///   refuses an APK whose signature differs from the installed app, so offering
///   one could only end in the installer's refusal.
library;

import 'app_version.dart';

/// The ABIs the pipeline publishes, best first — the order a device prefers
/// them in.
const publishedAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

/// One downloadable APK.
class UpdateAsset {
  const UpdateAsset({
    required this.abi,
    required this.url,
    required this.sizeBytes,
  });

  /// `arm64-v8a`, `armeabi-v7a` or `x86_64`.
  final String abi;

  /// `browser_download_url` — public, so the download needs no token.
  final String url;

  /// The asset's size on GitHub, used both for the label and to refuse a
  /// truncated download.
  final int sizeBytes;

  /// The download the owner is agreeing to: `18.0 MB`.
  String get sizeLabel =>
      '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// One release from the GitHub Releases API.
class AppRelease {
  const AppRelease({required this.version, required this.apks});

  final AppVersion version;

  /// The installable APKs it carries; empty when the release has none.
  final List<UpdateAsset> apks;

  /// The APK this device can install, or null when the release carries none.
  ///
  /// [deviceAbis] is the platform's `supportedAbis` — best first — so the first
  /// published ABI in that order wins.
  UpdateAsset? assetFor(List<String> deviceAbis) {
    for (final abi in deviceAbis) {
      for (final apk in apks) {
        if (apk.abi == abi) return apk;
      }
    }
    return null;
  }

  /// Parses a `releases/latest` payload; null when it carries no version this
  /// build can read.
  ///
  /// An empty [apks] is a valid parse: the release exists and is newer, it just
  /// has nothing this device can install, which the card says out loud instead
  /// of pretending the app is up to date.
  static AppRelease? fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;

    final apks = <UpdateAsset>[];
    for (final raw in _assets(json['assets'])) {
      // A release is published before its assets finish uploading, and only an
      // uploaded asset has a URL that answers.
      if (raw['state'] != 'uploaded') continue;
      final name = raw['name'];
      final url = raw['browser_download_url'];
      final size = raw['size'];
      if (name is! String || url is! String || size is! int) continue;
      final abi = _abiIn(name, tag);
      if (abi == null) continue;
      apks.add(UpdateAsset(abi: abi, url: url, sizeBytes: size));
    }
    return AppRelease(version: version, apks: List.unmodifiable(apks));
  }

  /// The ABI in an asset name, or null when that asset is not an installable
  /// APK of [tag].
  ///
  /// The middle segment has to be one of [publishedAbis] exactly, which is what
  /// rejects the AAB and the `-debugsigned` tail of an unsigned run.
  static String? _abiIn(String name, String tag) {
    final prefix = 'gymly-$tag-';
    if (!name.startsWith(prefix) || !name.endsWith('.apk')) return null;
    final abi = name.substring(prefix.length, name.length - '.apk'.length);
    return publishedAbis.contains(abi) ? abi : null;
  }

  static Iterable<Map<String, dynamic>> _assets(Object? raw) sync* {
    if (raw is! List) return;
    for (final asset in raw) {
      if (asset is Map<String, dynamic>) yield asset;
    }
  }
}
