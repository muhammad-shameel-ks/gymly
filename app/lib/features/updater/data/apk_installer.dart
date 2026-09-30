/// Hands a downloaded APK to Android's package installer.
///
/// The app never installs anything itself: it opens the file with the system
/// installer (`ACTION_VIEW` + `application/vnd.android.package-archive`), the
/// owner confirms there, and Android decides. That is the only path that keeps
/// the upload key as the trust anchor — the installer refuses an APK whose
/// signature differs from the installed app (`docs/ci-cd.md` § Signing) — and
/// the only one that needs no device-admin permission.
///
/// `open_filex` does the two parts that are easy to get wrong: it copies the
/// file into its own cache directory and shares it through its own
/// `FileProvider`, so no `file://` URI is ever exposed, and the app declares no
/// provider of its own.
library;

import 'dart:io';

import 'package:open_filex/open_filex.dart';

/// Thrown when Android did not open the file with an installer. The card keeps
/// the downloaded APK on screen and the caller shows the voice-spec message.
class ApkInstallException implements Exception {
  const ApkInstallException(this.reason);

  /// What the platform answered — for logs, never for the screen.
  final String reason;

  @override
  String toString() => 'ApkInstallException: $reason';
}

/// Opens a downloaded APK in the system installer.
abstract interface class ApkInstaller {
  Future<void> install(File apk);
}

/// [ApkInstaller] backed by the system installer through `open_filex`.
class OpenFilexInstaller implements ApkInstaller {
  const OpenFilexInstaller();

  /// What the installer accepts: the file's own name says nothing about it.
  static const apkMimeType = 'application/vnd.android.package-archive';

  @override
  Future<void> install(File apk) async {
    final result = await OpenFilex.open(apk.path, type: apkMimeType);
    if (result.type != ResultType.done) {
      throw ApkInstallException('${result.type.name}: ${result.message}');
    }
  }
}
