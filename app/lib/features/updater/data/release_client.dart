/// Reads the newest published release from the GitHub Releases API.
///
/// One request per tap of `Check for update` — never polled, never scheduled.
/// The endpoint needs no token (the repository is public), which also keeps it
/// inside the 60 requests/hour an unauthenticated caller gets per IP; the app
/// spends one.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/app_release.dart';

/// Thrown when the check itself failed: the request never answered, the API
/// refused it, or the payload is not a release this build can read.
///
/// The card shows one voice-spec message for all three, because the owner's
/// only move is the same in every case: try again.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.reason);

  /// Why the check failed — for logs, never for the screen.
  final String reason;

  @override
  String toString() => 'UpdateCheckException: $reason';
}

/// Client for the repository's latest release.
class ReleaseClient {
  const ReleaseClient(
    this._client, {
    this.owner = 'muhammad-shameel-ks',
    this.repo = 'gymly',
    this.timeout = const Duration(seconds: 20),
  });

  final http.Client _client;

  /// The GitHub account that owns the release pipeline. Both halves of the
  /// slug are the app's own repository, so they are constants, not settings.
  final String owner;
  final String repo;

  /// How long the check waits for an answer before it fails.
  final Duration timeout;

  /// The latest published release, or null when the repository has none yet
  /// (GitHub answers 404 — nothing to offer, which is not a failure).
  ///
  /// Throws [UpdateCheckException] when the check could not be made.
  Future<AppRelease?> latestRelease() async {
    final uri = Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');
    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ).timeout(timeout);
    } on Exception catch (e) {
      throw UpdateCheckException('request failed: $e');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw UpdateCheckException('HTTP ${response.statusCode}');
    }

    final Object? payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw UpdateCheckException('unreadable body: $e');
    }
    if (payload is! Map<String, dynamic>) {
      throw const UpdateCheckException('body is not a release object');
    }
    final release = AppRelease.fromJson(payload);
    if (release == null) {
      throw const UpdateCheckException('release carries no readable version');
    }
    return release;
  }
}
