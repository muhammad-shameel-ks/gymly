import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/features/updater/data/update_downloader.dart';
import 'package:gymly/features/updater/domain/app_release.dart';
import 'package:gymly/features/updater/domain/app_version.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The downloader is the only part of the update path that touches the
/// filesystem, so its failure modes are the ones worth pinning: a truncated
/// file must never reach the installer, and progress must be honest about
/// whether there is a length to measure against.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('gymly-updates'));
  tearDown(() => root.deleteSync(recursive: true));

  const asset = UpdateAsset(
    abi: 'arm64-v8a',
    url: 'https://example.test/gymly-v1.0.2-arm64-v8a.apk',
    sizeBytes: 8,
  );
  const version = AppVersion(1, 0, 2);

  UpdateDownloader downloader(http.Client client) =>
      UpdateDownloader(client, directory: () async => root);

  test('writes the asset and reports progress against the response length',
      () async {
    final progress = <double?>[];
    final client = MockClient.streaming((request, bodyStream) async {
      expect(request.url.toString(), asset.url);
      return http.StreamedResponse(
        Stream.fromIterable([utf8.encode('abcd'), utf8.encode('efgh')]),
        200,
        contentLength: 8,
      );
    });

    final file = await downloader(client)
        .download(asset, version: version, onProgress: progress.add);

    expect(file.readAsStringSync(), 'abcdefgh');
    expect(file.path, endsWith('gymly-1.0.2-arm64-v8a.apk'));
    expect(progress, [0.5, 1.0]);
  });

  test('refuses a truncated download and leaves no file behind', () async {
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(
        Stream.fromIterable([utf8.encode('abcd')]),
        200,
        contentLength: 4,
      ),
    );

    await expectLater(
      downloader(client).download(asset, version: version, onProgress: (_) {}),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(Directory('${root.path}/updates').listSync(), isEmpty);
  });

  test('reports progress as unknown when the response carries no length',
      () async {
    final progress = <double?>[];
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(
        Stream.fromIterable([utf8.encode('abcdefgh')]),
        200,
      ),
    );

    await downloader(client)
        .download(asset, version: version, onProgress: progress.add);

    expect(progress, [null]);
  });

  test('fails on a refusal instead of writing the error page to disk',
      () async {
    final client = MockClient((request) async => http.Response('nope', 500));

    await expectLater(
      downloader(client).download(asset, version: version, onProgress: (_) {}),
      throwsA(isA<UpdateDownloadException>()),
    );
  });
}
