import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/core/theme/app_theme.dart';
import 'package:gymly/core/widgets/app_sheet.dart';

/// Every sheet is pushed on the **root** navigator (`useRootNavigator: true`)
/// but opened from a tab's own context, whose `Navigator` is a *branch*
/// navigator. This pins that a sheet opened that way stays dismissible by scrim
/// tap and by drag — the property that broke in the field, where the leads
/// sheets could not be closed by tap, drag or back and the scrim tap opened
/// whatever sat underneath.
///
/// Scope, honestly: the field failure needed the real engine (it reproduced on
/// a device and in a browser, but *not* in this widget harness — a
/// caller-supplied `AnimationController` still dismisses fine here), so this is
/// an invariant guard, not a reproduction. The fix was verified end to end on
/// the device; the reasoning lives in `app_sheet.dart`'s library doc: timing is
/// a token, and the route keeps the controller ticked by its own navigator.
void main() {
  Future<GlobalKey<NavigatorState>> pumpShell(WidgetTester tester) async {
    final branchKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Navigator(
          key: branchKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('tab body'))),
          ),
        ),
      ),
    );
    return branchKey;
  }

  Future<void> openSheet(WidgetTester tester, BuildContext context) async {
    unawaited(
      showAppSheet<void>(
        context,
        builder: (_) =>
            const AppSheet(title: 'Probe sheet', child: Text('sheet body')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Probe sheet'), findsOneWidget);
  }

  testWidgets('a sheet opened from a tab closes on a barrier tap',
      (tester) async {
    final branchKey = await pumpShell(tester);
    await openSheet(tester, branchKey.currentContext!);

    // Well above the sheet: the scrim, over the tab body.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Probe sheet'), findsNothing);
    expect(find.text('tab body'), findsOneWidget);
  });

  testWidgets('a sheet opened from a tab closes when dragged down',
      (tester) async {
    final branchKey = await pumpShell(tester);
    await openSheet(tester, branchKey.currentContext!);

    // Dragged by its header, which sits outside the scrollable body.
    await tester.drag(find.text('Probe sheet'), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.text('Probe sheet'), findsNothing);
    expect(find.text('tab body'), findsOneWidget);
  });
}
