import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/features/updater/domain/app_release.dart';
import 'package:gymly/features/updater/domain/app_version.dart';

/// The parser is the boundary between the release pipeline's naming contract
/// and the phone: it has to keep exactly the assets this device can install and
/// drop everything else, including the two classes that would fail in the
/// installer (the AAB, and an unsigned run's `-debugsigned` APKs).
void main() {
  /// One asset, as the API reports it. Sizes are the real `v1.0.1` ones.
  Map<String, dynamic> asset(
    String name, {
    String state = 'uploaded',
    int size = 18889473,
  }) =>
      {
        'name': name,
        'size': size,
        'state': state,
        'content_type': 'application/vnd.android.package-archive',
        'browser_download_url':
            'https://github.com/muhammad-shameel-ks/gymly/releases/download/v1.0.1/$name',
      };

  /// The assets a signed `v1.0.1` release carries.
  List<Map<String, dynamic>> signedAssets() => [
        asset('gymly-v1.0.1-arm64-v8a.apk'),
        asset('gymly-v1.0.1-armeabi-v7a.apk', size: 16232651),
        asset('gymly-v1.0.1-x86_64.apk', size: 20389636),
        asset('gymly-v1.0.1.aab', size: 51795869),
      ];

  Map<String, dynamic> release({
    String tag = 'v1.0.1',
    List<Map<String, dynamic>>? assets,
  }) =>
      {
        'tag_name': tag,
        'name': 'Gymly $tag',
        'draft': false,
        'prerelease': false,
        'assets': assets ?? signedAssets(),
      };

  group('parsing', () {
    test('reads the tag and keeps the three installable APKs', () {
      final parsed = AppRelease.fromJson(release())!;

      expect(parsed.version, const AppVersion(1, 0, 1));
      expect(
        parsed.apks.map((apk) => apk.abi),
        ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
      );
      expect(parsed.apks.first.sizeBytes, 18889473);
      expect(parsed.apks.first.url, endsWith('gymly-v1.0.1-arm64-v8a.apk'));
    });

    test('drops the AAB, which the system installer cannot install', () {
      final parsed = AppRelease.fromJson(release())!;
      expect(parsed.apks.map((apk) => apk.abi), isNot(contains('aab')));
    });

    test('drops the APKs of a run without the upload key', () {
      final parsed = AppRelease.fromJson(
        release(
          assets: [
            asset('gymly-v1.0.1-arm64-v8a-debugsigned.apk'),
            asset('gymly-v1.0.1.aab'),
          ],
        ),
      )!;

      // The release is readable and newer, it just has nothing to install —
      // which the card says, instead of pretending the app is up to date.
      expect(parsed.version, const AppVersion(1, 0, 1));
      expect(parsed.apks, isEmpty);
    });

    test('drops assets of another tag and assets still uploading', () {
      final parsed = AppRelease.fromJson(
        release(
          assets: [
            asset('gymly-v1.0.0-arm64-v8a.apk'),
            asset('gymly-v1.0.1-arm64-v8a.apk', state: 'pending'),
          ],
        ),
      )!;

      expect(parsed.apks, isEmpty);
    });

    test('refuses a payload with no readable version', () {
      expect(AppRelease.fromJson({'name': 'Gymly'}), isNull);
      expect(AppRelease.fromJson({'tag_name': 'latest'}), isNull);
      expect(AppRelease.fromJson(const {}), isNull);
    });
  });

  group('choosing the APK for a device', () {
    test('takes the first ABI the device supports, best first', () {
      final parsed = AppRelease.fromJson(release())!;

      expect(
        parsed.assetFor(['arm64-v8a', 'armeabi-v7a'])!.abi,
        'arm64-v8a',
      );
      expect(
        parsed.assetFor(['x86_64', 'arm64-v8a'])!.abi,
        'x86_64',
      );
      expect(
        parsed.assetFor(['armeabi-v7a', 'armeabi'])!.abi,
        'armeabi-v7a',
      );
    });

    test('has nothing for an ABI the pipeline does not publish', () {
      final parsed = AppRelease.fromJson(release())!;
      expect(parsed.assetFor(['x86']), isNull);
      expect(parsed.assetFor(const []), isNull);
    });

    test('has nothing when the release carries no installable APK', () {
      final parsed = AppRelease.fromJson(
        release(assets: [asset('gymly-v1.0.1-arm64-v8a-debugsigned.apk')]),
      )!;
      expect(parsed.assetFor(['arm64-v8a']), isNull);
    });
  });

  test('labels the download in MB', () {
    final parsed = AppRelease.fromJson(release())!;
    expect(parsed.apks.first.sizeLabel, '18.0 MB');
    expect(parsed.apks[1].sizeLabel, '15.5 MB');
  });
}
