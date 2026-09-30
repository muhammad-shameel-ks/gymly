import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/features/updater/data/apk_installer.dart';
import 'package:gymly/features/updater/data/update_downloader.dart';
import 'package:gymly/features/updater/domain/app_version.dart';
import 'package:gymly/features/updater/providers/updater_providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The state machine is what the card renders, so every way a check, a download
/// and an install can end is pinned here. The transport is mocked but the JSON
/// is the pipeline's own shape, and the downloader is the real one — it is the
/// state transitions that are under test, not the bytes.
void main() {
  const apkBody = 'apk-bytes';
  const apkSize = 9;

  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('gymly-updater'));
  tearDown(() => root.deleteSync(recursive: true));

  String releaseJson({String tag = 'v1.0.2', String suffix = ''}) => jsonEncode({
        'tag_name': tag,
        'assets': [
          {
            'name': 'gymly-$tag-arm64-v8a$suffix.apk',
            'size': apkSize,
            'state': 'uploaded',
            'browser_download_url': 'https://github.com/gymly/$tag/arm64-v8a.apk',
          },
        ],
      });

  ProviderContainer harness({
    required ApkInstaller installer,
    List<UpdateState>? seen,
    String? releaseBody,
    int releaseStatus = 200,
    int downloadStatus = 200,
    List<String> abis = const ['arm64-v8a'],
    AppVersion installed = const AppVersion(1, 0, 1),
  }) {
    final client = MockClient.streaming((request, bodyStream) async {
      if (request.url.host == 'api.github.com') {
        final body = releaseBody ?? releaseJson();
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          releaseStatus,
          contentLength: body.length,
        );
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(apkBody)),
        downloadStatus,
        contentLength: apkBody.length,
      );
    });
    final container = ProviderContainer(
      overrides: [
        updaterHttpClientProvider.overrideWith((ref) => client),
        installedVersionProvider.overrideWith((ref) async => installed),
        deviceAbisProvider.overrideWith((ref) async => abis),
        updateDownloaderProvider.overrideWith(
          (ref) => UpdateDownloader(client, directory: () async => root),
        ),
        apkInstallerProvider.overrideWith((ref) => installer),
      ],
    );
    addTearDown(container.dispose);
    if (seen != null) {
      container.listen(updaterProvider, (_, next) => seen.add(next));
    }
    return container;
  }

  group('checking', () {
    test('is up to date when the published tag is not newer', () async {
      final container = harness(
        installer: _FakeInstaller(),
        releaseBody: releaseJson(tag: 'v1.0.1'),
      );

      await container.read(updaterProvider.notifier).check();

      expect(container.read(updaterProvider), isA<UpdateUpToDate>());
    });

    test('offers the APK for this device when the tag is newer', () async {
      final container = harness(installer: _FakeInstaller());

      await container.read(updaterProvider.notifier).check();

      final state = container.read(updaterProvider);
      expect(state, isA<UpdateAvailable>());
      final available = state as UpdateAvailable;
      expect(available.release.version, const AppVersion(1, 0, 2));
      expect(available.asset.abi, 'arm64-v8a');
    });

    test('offers nothing when the newer release has no file for this phone',
        () async {
      final container = harness(
        installer: _FakeInstaller(),
        releaseBody: releaseJson(suffix: '-debugsigned'),
      );

      await container.read(updaterProvider.notifier).check();

      final state = container.read(updaterProvider);
      expect(state, isA<UpdateNotInstallable>());
      expect((state as UpdateNotInstallable).version, const AppVersion(1, 0, 2));
    });

    test('offers nothing when the release has no APK for the device ABI',
        () async {
      final container = harness(
        installer: _FakeInstaller(),
        abis: const ['x86'],
      );

      await container.read(updaterProvider.notifier).check();

      expect(container.read(updaterProvider), isA<UpdateNotInstallable>());
    });

    test('fails when the API refuses', () async {
      final container = harness(
        installer: _FakeInstaller(),
        releaseStatus: 500,
      );

      await container.read(updaterProvider.notifier).check();

      expect(container.read(updaterProvider), isA<UpdateCheckFailed>());
    });

    test('is up to date while no release is published at all', () async {
      final container = harness(
        installer: _FakeInstaller(),
        releaseStatus: 404,
      );

      await container.read(updaterProvider.notifier).check();

      expect(container.read(updaterProvider), isA<UpdateUpToDate>());
    });
  });

  group('downloading and installing', () {
    test('writes the APK, then hands that file to the installer', () async {
      final installer = _FakeInstaller();
      final seen = <UpdateState>[];
      final container = harness(installer: installer, seen: seen);
      final updater = container.read(updaterProvider.notifier);

      await updater.check();
      await updater.download();

      final state = container.read(updaterProvider);
      expect(state, isA<UpdateDownloaded>());
      final downloaded = state as UpdateDownloaded;
      expect(downloaded.file.readAsStringSync(), apkBody);
      expect(seen.whereType<UpdateDownloading>().last.progress, 1.0);

      await updater.install();

      expect(installer.installed, downloaded.file);
    });

    test('keeps the offer on screen when the download fails', () async {
      final container = harness(
        installer: _FakeInstaller(),
        downloadStatus: 500,
      );
      final updater = container.read(updaterProvider.notifier);
      await updater.check();

      await expectLater(
        updater.download(),
        throwsA(isA<UpdateDownloadException>()),
      );

      expect(container.read(updaterProvider), isA<UpdateAvailable>());
    });

    test('keeps the downloaded APK when the installer refuses', () async {
      final container = harness(installer: _FakeInstaller(fail: true));
      final updater = container.read(updaterProvider.notifier);
      await updater.check();
      await updater.download();

      await expectLater(
        updater.install(),
        throwsA(isA<ApkInstallException>()),
      );

      expect(container.read(updaterProvider), isA<UpdateDownloaded>());
    });

    test('ignores a second check while a download is running', () async {
      final container = harness(installer: _FakeInstaller());
      final updater = container.read(updaterProvider.notifier);
      await updater.check();

      final downloading = updater.download();
      await updater.check();

      expect(container.read(updaterProvider), isA<UpdateDownloading>());
      await downloading;
      expect(container.read(updaterProvider), isA<UpdateDownloaded>());
    });
  });
}

/// Stands in for Android's installer, which no test can run.
class _FakeInstaller implements ApkInstaller {
  _FakeInstaller({this.fail = false});

  /// When true, the installer refuses the way the system one does when the
  /// signature does not match.
  final bool fail;

  File? installed;

  @override
  Future<void> install(File apk) async {
    if (fail) throw const ApkInstallException('refused');
    installed = apk;
  }
}
