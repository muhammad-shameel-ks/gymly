/// The app's back contract, pinned end to end through the real router.
///
/// System back is the platform's "up", in one order — top-most surface first,
/// then the tab, then out of the app (DESIGN.md §3, "Back"):
///
/// 1. a sheet/dialog (root navigator) or a page pushed into the current tab pops;
/// 2. on a tab with nothing left to pop, back moves to Dues — a secondary
///    top-level destination never closes the app, and the tab keeps its stack;
/// 3. only on Dues with nothing open does back leave the app;
/// 4. before sign-in, `/signup` is pushed on top of `/login`, so back returns to
///    login.
///
/// Every case here is a real failure that shipped: back on any tab root closed
/// the app outright (rule 2), and the duplicate-phone "Open member" action
/// pushed the member detail onto the *root* navigator — above the shell, with no
/// tab bar and outside the tab's stack (rule 1).
///
/// The harness mounts the whole app (`GymlyApp`) so the router, the shell's
/// `PopScope` and go_router's navigator walk are all the real ones; only data is
/// faked (a fixed gym scope, one member, repositories that never touch the
/// network). Back is driven the way the platform drives it: `popRoute` on
/// `flutter/navigation`, plus a predictive-back gesture on `flutter/backgesture`
/// (what Android 16 sends to apps targeting SDK 36). "The app left" is observed
/// as `SystemNavigator.pop` on the platform channel, which is exactly what the
/// framework sends when no route handled the pop.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/core/theme/theme_mode.dart';
import 'package:gymly/core/widgets/app_sheet.dart';
import 'package:gymly/features/auth/providers/auth_providers.dart';
import 'package:gymly/features/gyms/data/selected_gym.dart' as gyms;
import 'package:gymly/features/gyms/providers/gyms_providers.dart';
import 'package:gymly/features/home/data/dues_providers.dart';
import 'package:gymly/features/leads/application/leads_providers.dart' as leads;
import 'package:gymly/features/members/data/members_repository.dart';
import 'package:gymly/features/members/domain/member_money.dart';
import 'package:gymly/features/members/models/member.dart';
import 'package:gymly/features/members/models/payment.dart';
import 'package:gymly/features/members/providers/members_providers.dart';
import 'package:gymly/features/members/widgets/member_detail_screen.dart';
import 'package:gymly/features/plans/data/plans_repository.dart';
import 'package:gymly/features/plans/models/plan.dart';
import 'package:gymly/features/plans/providers/plans_providers.dart';
import 'package:gymly/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform calls the app made since the last `clearPlatformLog()`.
final List<String> platformLog = <String>[];

bool get _leftTheApp => platformLog.contains('SystemNavigator.pop');

const _member = Member(
  id: 'm1',
  gymId: 'g1',
  name: 'Asha',
  phone: '9000000001',
);

/// The one gym in scope; a fixed selection keeps the tabs on real screens.
class _FixedGym extends gyms.SelectedGymIdNotifier {
  @override
  String? build() => 'g1';
}

class _FakeMembers extends MembersRepository {
  _FakeMembers() : super(Supabase.instance.client);

  @override
  Future<Member> memberById(String memberId) async => _member;

  @override
  Future<List<Subscription>> stretchesFor(String memberId) async =>
      const <Subscription>[];

  @override
  Future<List<Payment>> paymentsFor(String memberId) async => const <Payment>[];

  /// Every create collides with [_member]: the duplicate-phone path.
  @override
  Future<Member> createMember({
    required String gymId,
    required String name,
    required String phone,
    String? note,
    String? planId,
    int? priceOverride,
    int? firstPayment,
  }) async => throw const DuplicateMemberException(_member);
}

class _FakePlans extends PlansRepository {
  _FakePlans() : super(Supabase.instance.client);

  @override
  Future<List<Plan>> listPlans({required String gymId}) async => const <Plan>[];
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'sb_publishable_test',
      debug: false,
    );
  });

  /// Mounts the app with fake data. [loggedIn] false renders the public routes.
  Future<void> pumpApp(WidgetTester tester, {bool loggedIn = true}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformLog.add(call.method);
        return null;
      },
    );
    final tab = computeTab(
      stretches: const [],
      payments: const [],
      today: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isLoggedInProvider.overrideWithValue(loggedIn),
          leads.selectedGymIdProvider.overrideWith(
            (ref) => ref.watch(gyms.selectedGymIdProvider),
          ),
          gyms.selectedGymIdProvider.overrideWith(_FixedGym.new),
          gymsListProvider.overrideWith(
            (ref) => const [Gym(id: 'g1', ownerId: 'o1', name: 'Iron Gym')],
          ),
          duesFeedProvider.overrideWith(
            (ref) => [
              DuesEntry(member: _member, tab: tab, gymName: 'Iron Gym'),
            ],
          ),
          membersListProvider.overrideWith(
            (ref, q) => [MemberWithDues(member: _member, tab: tab)],
          ),
          membersRepositoryProvider.overrideWith((ref) => _FakeMembers()),
          plansRepositoryProvider.overrideWith((ref) => _FakePlans()),
        ],
        child: const GymlyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    platformLog.clear();
  }

  /// Frames enough for a push's hero post-frame and its route transition.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The platform's back: the `popRoute` method call a button/hardware press
  /// sends (`flutter/navigation`).
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await settle(tester);
  }

  /// The platform's back gesture: Android 16's predictive-back method calls.
  Future<void> swipeBack(WidgetTester tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const codec = StandardMethodCodec();
    final args = <String, Object?>{
      'touchOffset': <double>[0, 400],
      'progress': 0.0,
      'swipeEdge': 0,
    };
    await messenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(MethodCall('startBackGesture', args)),
      (_) {},
    );
    await messenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(MethodCall('updateBackGestureProgress', args)),
      (_) {},
    );
    await messenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(const MethodCall('commitBackGesture')),
      (_) {},
    );
    await settle(tester);
  }

  Finder tabButton(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  /// The destination the bar shows (0 = Dues), or null when the shell is not on
  /// screen (a sheet or a root-navigator page covers it).
  int? selectedTab(WidgetTester tester) {
    final bar = find.byType(NavigationBar);
    if (bar.evaluate().isEmpty) return null;
    return tester.widget<NavigationBar>(bar).selectedIndex;
  }

  Future<void> tapAt(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  testWidgets(
    'back on a secondary tab moves to Dues, it never leaves the app',
    (tester) async {
      await pumpApp(tester);
      expect(selectedTab(tester), 0);

      await tapAt(tester, tabButton('Leads'));
      expect(selectedTab(tester), 2);

      await pressBack(tester);
      expect(selectedTab(tester), 0, reason: 'back is the tab model\'s up');
      expect(
        _leftTheApp,
        isFalse,
        reason: 'a secondary tab must not close the app',
      );

      // Only from Dues, with nothing open, does back leave the app.
      await pressBack(tester);
      expect(_leftTheApp, isTrue);
    },
  );

  testWidgets('the gesture path obeys the same rule', (tester) async {
    await pumpApp(tester);
    await tapAt(tester, tabButton('Plans'));

    await swipeBack(tester);
    expect(selectedTab(tester), 0);
    expect(_leftTheApp, isFalse);
  });

  testWidgets('back pops a page pushed into the tab before it moves tabs', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapAt(tester, tabButton('Members'));
    await tapAt(tester, find.text('Asha').first);
    expect(find.byType(MemberDetailScreen), findsOneWidget);
    // The detail belongs to the tab: the bar stays on screen under it.
    expect(selectedTab(tester), 1);

    await pressBack(tester);
    expect(find.byType(MemberDetailScreen), findsNothing);
    expect(selectedTab(tester), 1);
    expect(_leftTheApp, isFalse);

    await pressBack(tester);
    expect(selectedTab(tester), 0);
    expect(_leftTheApp, isFalse);
  });

  testWidgets('back dismisses a sheet over the shell without leaving the app', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapAt(tester, tabButton('Members'));
    await tapAt(tester, find.text('Add member'));
    expect(find.byType(AppSheet), findsOneWidget);

    await pressBack(tester);
    expect(find.byType(AppSheet), findsNothing);
    expect(selectedTab(tester), 1, reason: 'the sheet closed, the tab stayed');
    expect(_leftTheApp, isFalse);
  });

  testWidgets('the duplicate-phone action opens the member inside the tab', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapAt(tester, tabButton('Members'));
    await tapAt(tester, find.text('Add member'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha');
    await tester.enterText(find.byType(TextFormField).at(1), '9000000001');
    await settle(tester);
    // The sheet's own CTA shares its label with the tab's FAB.
    await tapAt(tester, find.text('Add member').last);
    expect(find.text('Open Asha'), findsOneWidget);

    await tapAt(tester, find.text('Open Asha'));
    expect(find.byType(AppSheet), findsNothing);
    expect(find.byType(MemberDetailScreen), findsOneWidget);
    expect(
      selectedTab(tester),
      1,
      reason: 'the detail joins the tab stack, not the root navigator',
    );

    await pressBack(tester);
    expect(find.byType(MemberDetailScreen), findsNothing);
    expect(selectedTab(tester), 1);
    expect(_leftTheApp, isFalse);
  });

  testWidgets('back from signup returns to login', (tester) async {
    await pumpApp(tester, loggedIn: false);
    expect(find.text('Create account'), findsOneWidget);

    await tapAt(tester, find.text('Create account'));
    expect(find.text('Sign up'), findsOneWidget);

    await pressBack(tester);
    expect(
      find.text('Create account'),
      findsOneWidget,
      reason: 'login is below signup, not replaced by it',
    );
    expect(_leftTheApp, isFalse);
  });
}
