/// The app's version as `X.Y.Z`, parsed from either side of the update check.
///
/// Two sources spell it differently and neither is trusted input: the installed
/// version comes from `package_info_plus` (which reads the built
/// `pubspec.yaml`, so `1.0.1+2`) and the published one from the release tag the
/// pipeline cuts (`v1.0.1`, per `docs/ci-cd.md`). Parsing takes the `X.Y.Z`
/// head and ignores what surrounds it, so neither side has to know the other's
/// spelling.
///
/// Only those three numbers decide "is this newer". The build number is not an
/// input: a release build takes it from the CI run number
/// (`--build-number=${{ github.run_number }}`), so it orders nothing.
library;

/// One parsed `major.minor.patch`.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Parses `1.2.3`, `v1.2.3`, `1.2.3+4` or `v1.2.3-rc.1`; null when [raw]
  /// carries no `X.Y.Z` head at all.
  ///
  /// A prerelease tag cannot arrive from `releases/latest` (GitHub leaves
  /// prereleases out of it), so the suffix is dropped rather than ordered.
  static AppVersion? tryParse(String raw) {
    final match = _head.firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static final _head = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)');

  /// True when this version is strictly newer than [other].
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  /// `1.2.3` — how the owner reads it.
  @override
  String toString() => '$major.$minor.$patch';
}
