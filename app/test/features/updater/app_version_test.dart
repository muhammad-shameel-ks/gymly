import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/features/updater/domain/app_version.dart';

/// [AppVersion] is what decides whether the app offers an update, and it reads
/// two spellings: the release tag (`v1.0.1`) and the installed version
/// (`1.0.1+2`). Both are covered here, along with the ordering the offer
/// depends on.
void main() {
  group('parsing', () {
    test('reads a bare version', () {
      final version = AppVersion.tryParse('1.0.1')!;
      expect(version.major, 1);
      expect(version.minor, 0);
      expect(version.patch, 1);
      expect(version.toString(), '1.0.1');
    });

    test('reads a release tag with the leading v', () {
      expect(AppVersion.tryParse('v2.13.4'), const AppVersion(2, 13, 4));
    });

    test('drops the build number the installed version carries', () {
      expect(AppVersion.tryParse('1.0.1+2'), const AppVersion(1, 0, 1));
    });

    test('drops a prerelease suffix', () {
      expect(AppVersion.tryParse('v1.2.0-rc.1'), const AppVersion(1, 2, 0));
    });

    test('trims whitespace', () {
      expect(AppVersion.tryParse('  v1.0.1\n'), const AppVersion(1, 0, 1));
    });

    test('refuses anything without an X.Y.Z head', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse('1.0'), isNull);
      expect(AppVersion.tryParse('v1.0.x'), isNull);
    });
  });

  group('ordering', () {
    test('compares each part in turn', () {
      expect(
        const AppVersion(1, 0, 2).isNewerThan(const AppVersion(1, 0, 1)),
        isTrue,
      );
      expect(
        const AppVersion(1, 1, 0).isNewerThan(const AppVersion(1, 0, 9)),
        isTrue,
      );
      expect(
        const AppVersion(2, 0, 0).isNewerThan(const AppVersion(1, 9, 9)),
        isTrue,
      );
    });

    test('is not newer when equal or older', () {
      expect(
        const AppVersion(1, 0, 1).isNewerThan(const AppVersion(1, 0, 1)),
        isFalse,
      );
      expect(
        const AppVersion(1, 0, 1).isNewerThan(const AppVersion(1, 0, 2)),
        isFalse,
      );
    });

    test('a tag and the installed version of the same release are equal', () {
      expect(
        AppVersion.tryParse('v1.0.1')!.isNewerThan(AppVersion.tryParse('1.0.1+2')!),
        isFalse,
      );
    });
  });
}
