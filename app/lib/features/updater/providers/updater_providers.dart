/// Riverpod providers for the in-app updater.
///
/// The updater is one state machine ([updaterProvider]): the card renders it,
/// and each transition has a single writer, so a stale `Downloading…` cannot
/// survive a second tap. Everything platform-shaped sits behind a provider —
/// the installed version, the device's ABIs, the HTTP client, the installer —
/// so tests drive the whole sequence without a device.
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../data/apk_installer.dart';
import '../data/release_client.dart';
import '../data/update_downloader.dart';
import '../domain/app_release.dart';
import '../domain/app_version.dart';

/// True where an APK can be installed. Overridden in tests, which run on a
/// host where `Platform.isAndroid` is false.
final isAndroidProvider = Provider<bool>(
  (ref) => Platform.isAndroid,
  name: 'isAndroid',
);

/// The installed version, read from the platform — never from a constant in
/// the repo, which would drift from the release that was actually built.
final installedVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final version = AppVersion.tryParse(info.version);
  if (version == null) {
    throw StateError('Unreadable installed version: ${info.version}');
  }
  return version;
}, name: 'installedVersion');

/// The device's `supportedAbis`, best first: which APK this phone can run.
final deviceAbisProvider = FutureProvider<List<String>>((ref) async {
  final info = await DeviceInfoPlugin().androidInfo;
  return info.supportedAbis;
}, name: 'deviceAbis');

/// One client for the check and the download; closed with the container.
final updaterHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}, name: 'updaterHttpClient');

final releaseClientProvider = Provider<ReleaseClient>(
  (ref) => ReleaseClient(ref.watch(updaterHttpClientProvider)),
  name: 'releaseClient',
);

final updateDownloaderProvider = Provider<UpdateDownloader>(
  (ref) => UpdateDownloader(ref.watch(updaterHttpClientProvider)),
  name: 'updateDownloader',
);

final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => const OpenFilexInstaller(),
  name: 'apkInstaller',
);

/// The update state the card renders.
final updaterProvider = NotifierProvider<Updater, UpdateState>(Updater.new);

/// What the update card shows: one state, one control.
sealed class UpdateState {
  const UpdateState();
}

/// Nothing has been checked in this session.
class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

/// A check is in flight.
class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

/// The installed version is the newest published one.
class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

/// A newer release exists and carries an APK for this device.
class UpdateAvailable extends UpdateState {
  const UpdateAvailable({required this.release, required this.asset});

  final AppRelease release;
  final UpdateAsset asset;
}

/// A newer release exists, but nothing in it installs on this device — an
/// unsigned run's APKs, or an ABI the pipeline does not publish.
class UpdateNotInstallable extends UpdateState {
  const UpdateNotInstallable(this.version);

  final AppVersion version;
}

/// The APK is being downloaded. [progress] is null while the response carries
/// no length to measure against.
class UpdateDownloading extends UpdateState {
  const UpdateDownloading({
    required this.release,
    required this.asset,
    this.progress,
  });

  final AppRelease release;
  final UpdateAsset asset;
  final double? progress;
}

/// The APK is on disk, waiting for the installer.
class UpdateDownloaded extends UpdateState {
  const UpdateDownloaded({
    required this.release,
    required this.asset,
    required this.file,
  });

  final AppRelease release;
  final UpdateAsset asset;
  final File file;
}

/// The check itself failed: no answer, a refusal, or a payload this build
/// cannot read.
class UpdateCheckFailed extends UpdateState {
  const UpdateCheckFailed();
}

/// Owns the check → download → install sequence.
class Updater extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateIdle();

  /// Asks for the latest release and compares it with the installed version.
  ///
  /// No-op while a check or a download is already running. Every failure lands
  /// on [UpdateCheckFailed] rather than throwing: the card is the report.
  Future<void> check() async {
    final current = state;
    if (current is UpdateChecking || current is UpdateDownloading) return;
    state = const UpdateChecking();
    try {
      final installed = await ref.read(installedVersionProvider.future);
      final release = await ref.read(releaseClientProvider).latestRelease();
      if (release == null || !release.version.isNewerThan(installed)) {
        state = const UpdateUpToDate();
        return;
      }
      final asset = release.assetFor(await ref.read(deviceAbisProvider.future));
      state = asset == null
          ? UpdateNotInstallable(release.version)
          : UpdateAvailable(release: release, asset: asset);
    } catch (_) {
      // Nothing else to tell the owner, and no state that would let them act.
      state = const UpdateCheckFailed();
    }
  }

  /// Downloads the offered update.
  ///
  /// Throws [UpdateDownloadException] when it fails, after putting the offer
  /// back on screen — the owner's next move is tapping Download again, so the
  /// card has to stay exactly where it was.
  Future<void> download() async {
    final current = state;
    if (current is! UpdateAvailable) return;
    state = UpdateDownloading(
      release: current.release,
      asset: current.asset,
      progress: 0,
    );
    try {
      final file = await ref.read(updateDownloaderProvider).download(
            current.asset,
            version: current.release.version,
            onProgress: (progress) {
              final running = state;
              if (running is UpdateDownloading) {
                state = UpdateDownloading(
                  release: running.release,
                  asset: running.asset,
                  progress: progress,
                );
              }
            },
          );
      state = UpdateDownloaded(
        release: current.release,
        asset: current.asset,
        file: file,
      );
    } catch (_) {
      state = current;
      rethrow;
    }
  }

  /// Opens the downloaded APK in the system installer.
  ///
  /// Throws [ApkInstallException] when Android refuses; the state stays
  /// [UpdateDownloaded] so the control is still there to try again.
  Future<void> install() async {
    final current = state;
    if (current is! UpdateDownloaded) return;
    await ref.read(apkInstallerProvider).install(current.file);
  }
}
