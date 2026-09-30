import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/core/theme/app_theme.dart';
import 'package:gymly/features/updater/domain/app_release.dart';
import 'package:gymly/features/updater/domain/app_version.dart';
import 'package:gymly/features/updater/providers/updater_providers.dart';
import 'package:gymly/features/updater/widgets/update_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The card is the whole feature as the owner sees it, so the copy per state is
/// the contract: one caption that is true, one control that says what the tap
/// does, and a failure that names what happened and offers a way out.
void main() {
  const asset = UpdateAsset(
    abi: 'arm64-v8a',
    url: 'https://github.com/gymly/v1.0.2/arm64-v8a.apk',
    sizeBytes: 18889473,
  );
  const release = AppRelease(version: AppVersion(1, 0, 2), apks: [asset]);

  Future<void> pump(
    WidgetTester tester, {
    UpdateState state = const UpdateIdle(),
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installedVersionProvider.overrideWith(
            (ref) async => const AppVersion(1, 0, 1),
          ),
          updaterProvider.overrideWith(() => _Given(state)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: UpdateCard()),
        ),
      ),
    );
    // A state that animates forever (an indeterminate bar, a spinner) never
    // settles, so those tests pump a single frame instead.
    if (settle) await tester.pumpAndSettle();
    await tester.pump();
  }

  testWidgets('shows the installed version and one control', (tester) async {
    await pump(tester);

    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.0.1'), findsOneWidget);
    expect(find.text('Check for update'), findsOneWidget);
  });

  testWidgets('up to date says so, and the check stays available',
      (tester) async {
    await pump(tester, state: const UpdateUpToDate());

    expect(find.text("You're on the latest version."), findsOneWidget);
    expect(find.text('Check for update'), findsOneWidget);
  });

  testWidgets('an update shows the version, the size and the download',
      (tester) async {
    await pump(
      tester,
      state: const UpdateAvailable(release: release, asset: asset),
    );

    expect(find.text('Version 1.0.2 is available · 18.0 MB'), findsOneWidget);
    expect(find.text('Download update'), findsOneWidget);
  });

  testWidgets('a download in flight shows its progress', (tester) async {
    await pump(
      tester,
      state: const UpdateDownloading(
        release: release,
        asset: asset,
        progress: 0.45,
      ),
    );

    expect(find.text('Downloading… 45%'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      0.45,
    );
  });

  testWidgets('a download with no length to measure shows no percentage',
      (tester) async {
    await pump(
      tester,
      state: const UpdateDownloading(
        release: release,
        asset: asset,
      ),
      settle: false,
    );

    expect(find.text('Downloading…'), findsOneWidget);
  });

  testWidgets('a downloaded update warns about the installer prompt',
      (tester) async {
    await pump(
      tester,
      state: UpdateDownloaded(
        release: release,
        asset: asset,
        file: File('${Directory.systemTemp.path}/gymly-1.0.2-arm64-v8a.apk'),
      ),
    );

    expect(find.text('Update downloaded.'), findsOneWidget);
    expect(
      find.text('Android will ask you to allow installing from Gymly.'),
      findsOneWidget,
    );
    expect(find.text('Install update'), findsOneWidget);
  });

  testWidgets('a release with no file for this phone says which version',
      (tester) async {
    await pump(tester, state: const UpdateNotInstallable(AppVersion(1, 0, 2)));

    expect(
      find.text('Version 1.0.2 has no file for this phone.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a failed check names the next move', (tester) async {
    await pump(tester, state: const UpdateCheckFailed());

    expect(
      find.text("Couldn't check for updates. Check your connection, then try "
          'again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('checking disables the control while it runs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installedVersionProvider.overrideWith(
            (ref) async => const AppVersion(1, 0, 1),
          ),
          updaterProvider.overrideWith(() => _Given(const UpdateChecking())),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: UpdateCard()),
        ),
      ),
    );
    // Not `pumpAndSettle`: the spinner never settles.
    await tester.pump();

    expect(find.text('Checking…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('the check reaches the API and reports what it found',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.github.com');
      expect(request.url.path, '/repos/muhammad-shameel-ks/gymly/releases/latest');
      return http.Response(
        jsonEncode({
          'tag_name': 'v1.0.1',
          'assets': const [],
        }),
        200,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installedVersionProvider.overrideWith(
            (ref) async => const AppVersion(1, 0, 1),
          ),
          updaterHttpClientProvider.overrideWith((ref) => client),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: UpdateCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();

    expect(find.text("You're on the latest version."), findsOneWidget);
  });
}

/// A notifier pinned to one state, so every card state renders without a
/// network, a device or a release.
class _Given extends Updater {
  _Given(this._state);

  final UpdateState _state;

  @override
  UpdateState build() => _state;
}
