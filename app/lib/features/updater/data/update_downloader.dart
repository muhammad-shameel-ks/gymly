/// Streams a release APK into the app's temporary directory.
///
/// The file is written where Android lets the app write without asking
/// (`getTemporaryDirectory()`), and the caller hands that path to the system
/// installer. It is never read by the app itself, so nothing depends on the
/// file surviving: a stale one is overwritten by the next download.
///
/// Integrity: the byte count has to match the size GitHub reports for the
/// asset. That is the one failure the app can cause and catch on its own — an
/// interrupted download — and it is caught here rather than handed to the
/// installer as a file that will not parse. Beyond that the APK's signature is
/// the trust anchor: Android refuses an install whose key differs from the
/// installed app, so a tampered payload cannot land even if it arrives intact.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/app_release.dart';
import '../domain/app_version.dart';

/// Thrown when the download could not be completed. The card keeps the offer
/// on screen and the caller shows the voice-spec message.
class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.reason);

  /// Why the download failed — for logs, never for the screen.
  final String reason;

  @override
  String toString() => 'UpdateDownloadException: $reason';
}

/// Downloads one [UpdateAsset] to a file.
class UpdateDownloader {
  const UpdateDownloader(
    this._client, {
    this.directory = _appTemporaryDirectory,
    this.timeout = const Duration(seconds: 20),
    this.stallTimeout = const Duration(seconds: 30),
  });

  final http.Client _client;

  /// Where the APK is written. Defaults to the app's own temporary directory,
  /// which Android lets the app write without asking; tests pass their own.
  final Future<Directory> Function() directory;

  /// How long the download waits for the response to start.
  final Duration timeout;

  /// How long it waits between two chunks before calling the connection dead.
  /// A 19 MB APK on a slow link keeps producing bytes, so this only fires on a
  /// connection that has actually stopped.
  final Duration stallTimeout;

  /// Downloads [asset] and returns the file it wrote.
  ///
  /// [onProgress] receives `0..1`, or null while the response carries no length
  /// to measure against. Throws [UpdateDownloadException] on any failure,
  /// including a truncated file, which is deleted before the throw.
  Future<File> download(
    UpdateAsset asset, {
    required AppVersion version,
    required ValueChanged<double?> onProgress,
  }) async {
    final updates = Directory('${(await directory()).path}/updates');
    await updates.create(recursive: true);
    // Built from parsed parts, never from the asset's own name: nothing from
    // the network reaches the path.
    final file = File('${updates.path}/gymly-$version-${asset.abi}.apk');

    final http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', Uri.parse(asset.url)))
          .timeout(timeout);
    } on Exception catch (e) {
      throw UpdateDownloadException('request failed: $e');
    }
    if (response.statusCode != 200) {
      throw UpdateDownloadException('HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(stallTimeout)) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total == 0 ? null : (received / total).clamp(0, 1).toDouble());
      }
    } on Exception catch (e) {
      await sink.close();
      await _discard(file);
      throw UpdateDownloadException('interrupted: $e');
    }
    await sink.close();

    if (received != asset.sizeBytes) {
      await _discard(file);
      throw UpdateDownloadException(
        'truncated: $received of ${asset.sizeBytes} bytes',
      );
    }
    return file;
  }

  /// Deletes a partial file, ignoring the failure of the delete itself: the
  /// download's own error is the one worth reporting.
  static Future<void> _discard(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Nothing to clean up.
    }
  }
}

/// The app's own temporary directory — the one place Android lets the app
/// write without asking.
Future<Directory> _appTemporaryDirectory() => getTemporaryDirectory();
