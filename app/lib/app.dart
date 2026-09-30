/// App shell: GoRouter with 4 bottom tabs + header gym-switcher.
///
/// Tabs: Dues · Members · Leads · Plans — named for what they show, in the
/// owner's words (docs/voice.md). Each tab owns its own
/// Scaffold; the shell contributes a shared header row
/// ([ShellHeader]: title + [GymSwitcher]) that every tab renders at the top
/// of its body.
///
/// Gym scope: reads the canonical [selectedGymIdProvider] (null = All gyms).
/// Home aggregates all gyms when null; Members/Leads/Plans take
/// `gymId` and show a pick-gym prompt when null (they already do).
///
/// Auth: [authRedirect] gates every route — logged-out owners go to
/// `/login`; logged-in owners visiting `/login` or `/signup` bounce to `/`.
/// The router is built **once**; `refreshListenable` re-evaluates the
/// redirect on sign-in/sign-out so the gate reacts without rebuilding the
/// navigator or restarting the app.
///
/// Profile: `/profile` is a top-level route inside the shell (its own
/// branch, no bottom tab) hosting the theme switcher, the updater and logout.
///
/// Slice-provider unification (single instances, no duplicates):
/// - canonical gym selection: `features/gyms/data/selected_gym.dart`
///   (`selectedGymIdProvider`); Leads keeps a local provider of the same
///   name as an override seam — integration overrides it with the canonical:
///   ```dart
///   ProviderScope(overrides: [
///     leadsSelectedGym.overrideWith(
///       (ref) => ref.watch(canonicalSelectedGym),
///     ),
///   ])
///   ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/motion/motion.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_tokens.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/gyms/data/selected_gym.dart'
    show selectedGymIdProvider;
import 'features/gyms/screens/gyms_screen.dart';
import 'features/gyms/widgets/gym_switcher.dart';
import 'features/home/widgets/home_screen.dart';
import 'features/leads/presentation/leads_screen.dart';
import 'features/members/widgets/members_screen.dart';
import 'features/plans/widgets/plans_screen.dart';
import 'features/profile/screens/profile_screen.dart';

/// Router provider for the app widget.
///
/// The [GoRouter] is built **once** per [ProviderScope]: [isLoggedInProvider]
/// is only *read* (inside [authRedirect]), never watched, so auth emissions
/// (initial session, token refresh, app resume) no longer rebuild it and the
/// navigator/shell stays mounted. Gate re-evaluation is driven by
/// [refreshListenable] instead — a [ChangeNotifier] bridging
/// `ref.listen(isLoggedInProvider, …)`.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshListenable(ref);
  ref.onDispose(refresh.dispose);
  return buildRouter(ref, refreshListenable: refresh);
});

/// Bridges Riverpod auth state into a [Listenable] for GoRouter's
/// `refreshListenable`, so the redirect re-fires without a router rebuild.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(isLoggedInProvider, (_, _) => notifyListeners());
  }
}

/// Builds the app router once; [refreshListenable] re-fires [authRedirect] on
/// sign-in/sign-out so the gate reacts without an app restart.
GoRouter buildRouter(Ref ref, {required Listenable refreshListenable}) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) => authRedirect(
      loggedIn: ref.read(isLoggedInProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                // HomeScreen owns its own header (title + GymSwitcher);
                // the shell adds nothing above it.
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/members',
                builder: (context, state) => const _MembersTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                // LeadsScreen owns its own AppBar; the shell adds no
                // header above it (avoids a double title).
                path: '/leads',
                builder: (context, state) => const LeadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plans',
                builder: (context, state) => const _PlansTab(),
              ),
              GoRoute(
                // GymsScreen owns its own Scaffold + AppBar, so no shell
                // header here (a shell title would double up).
                path: '/gyms',
                builder: (context, state) => const GymsScreen(),
              ),
            ],
          ),
          // Profile is a top-level route inside the shell but not a bottom
          // tab, so it gets its own branch; the bar clamps its selected index
          // to [_TabShell._tabCount] destinations (see `_TabShell`).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Bottom-tab shell: tab content + 4-tab bar (accent = active tab ONLY).
///
/// Naming follows the voice spec (`docs/voice.md`): a tab is called what it
/// shows, in the owner's words — `Dues` (the Home screen's own title), not
/// "Home". Tooltips default to the label, so they are not spelled twice.
///
/// Feel comes from `core/motion`, never from a local animation: a destination
/// change fires [Haptics.select] (a tab is a discrete value moving), slides the
/// arriving tab's content in from the direction of travel ([TabTransition],
/// 250 ms, in place around the shell), and the selected icon pops once
/// ([MotionSpec.pop]; the quiet return uses [MotionSpec.toggle]). Reduce Motion
/// drops the slide and the scale and keeps the colour swap, the cross-fade and
/// the haptic.
///
/// [TabTransition] wraps the body only — the bar is chrome and does not move —
/// and it is a transform wrapper around the live [StatefulNavigationShell]: the
/// shell is never re-created, re-keyed or mounted twice, so each branch's
/// `Navigator` (and its `GlobalKey`) stays exactly one.
///
/// **Sheets are root-navigator routes** (`core/widgets/app_sheet.dart`):
/// `showAppSheet` always opens its sheet with `useRootNavigator: true`, so the
/// sheet sits above this shell's `Scaffold` — the app-wide scrim covers the
/// `NavigationBar` and any FAB (nothing underneath a sheet can open a second
/// one), and the root navigator is the one that answers back. This matters
/// *because* the branch navigators live inside `Scaffold.body`: a sheet pushed
/// onto one of those renders inside the tab, clipped, with a barrier that stops
/// at the bar, and back is routed through the shell instead of the app's
/// top-most route.
///
/// **Back is the tab model's "up".** The shell is wrapped in one [PopScope]
/// that claims the pop only while a destination other than Dues is selected:
/// back from Members/Leads/Plans (or from a branch-only route) moves to Dues —
/// the platform's rule for a secondary top-level destination — and only on Dues
/// does the pop bubble out of the app. Claiming it, rather than letting it
/// bubble, is also what tells Android the framework handles back
/// (`SystemNavigator.setFrameworkHandlesBack`), so a secondary tab no longer
/// hands the gesture to the system's back-to-home animation.
///
/// This `PopScope` sits on the **shell page** (the root navigator's route), not
/// on a branch navigator, so it cannot swallow a sheet's or a pushed page's
/// back: those are separate routes, and go_router walks the branch navigator —
/// and the sheet, which the root navigator holds above the shell page — before
/// the shell's route is ever asked. It only sees the pop that has nothing left
/// above it, which is exactly the case it answers. The selected index stays
/// clamped to [_tabCount] for the branch-only routes (`/profile`).
class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  /// Bottom-tab destinations; the bar clamps [StatefulNavigationShell]'s
  /// index to this (the shell may have more branches, e.g. `/profile`).
  static const int _tabCount = 4;

  /// Bar order: Dues · Members · Leads · Plans.
  static const List<String> _labels = ['Dues', 'Members', 'Leads', 'Plans'];
  // Icon and label must agree: the first tab is the dues ledger, so it gets a
  // ledger, not a house.
  static const List<IconData> _icons = [
    Icons.receipt_long_outlined,
    Icons.people_outline,
    Icons.person_add_outlined,
    Icons.card_membership_outlined,
  ];
  static const List<IconData> _selectedIcons = [
    Icons.receipt_long,
    Icons.people,
    Icons.person_add,
    Icons.card_membership,
  ];

  final StatefulNavigationShell shell;

  /// Moves between the 4 destinations. The selection haptic fires only when
  /// the destination actually changes; re-tapping the active tab just returns
  /// to its root, silently.
  void _go(int index) {
    if (index != shell.currentIndex) Haptics.select();
    shell.goBranch(index, initialLocation: true);
  }

  /// Back on a destination that is not Dues: the same move as tapping the Dues
  /// tab, except that it keeps Dues' own stack (`goBranch` without
  /// `initialLocation` — a *press* on the active tab is what resets it).
  void _backToDues() {
    Haptics.select();
    shell.goBranch(0);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final index =
        shell.currentIndex < _tabCount ? shell.currentIndex : _tabCount - 1;
    return PopScope(
      // Claim the pop for every destination but the first (the branch-only
      // `/profile` included): back never leaves the app from a secondary tab —
      // it moves to Dues first. The class doc covers why this cannot swallow a
      // sheet's or a pushed page's own back.
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _backToDues();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        // The body is transformed in place by [TabTransition] — the shell itself
        // is never swapped or re-keyed, so branch navigators and tab state live.
        body: TabTransition(index: shell.currentIndex, child: shell),
        bottomNavigationBar: SafeArea(
          top: false,
          child: NavigationBar(
            backgroundColor: p.bg,
            indicatorColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (Set<WidgetState> states) {
                final selected = states.contains(WidgetState.selected);
                return AppType.caption.copyWith(
                  color: selected ? p.accentText : p.secondary,
                );
              },
            ),
            destinations: [
              for (var i = 0; i < _tabCount; i++)
                NavigationDestination(
                  icon: _TabIcon(
                    selected: i == index,
                    icon: i == index ? _selectedIcons[i] : _icons[i],
                  ),
                  label: _labels[i],
                ),
            ],
            selectedIndex: index,
            onDestinationSelected: _go,
          ),
        ),
      ),
    );
  }
}

/// One bottom-nav icon: pops once when its destination becomes selected.
///
/// Reduce Motion keeps the glyph/colour change and the haptic, and drops the
/// scale, so the selected icon never rests enlarged.
class _TabIcon extends StatefulWidget {
  const _TabIcon({required this.selected, required this.icon});

  /// Drawn 8% larger at the top of a selection pop.
  static const double pop = 0.08;

  final bool selected;
  final IconData icon;

  @override
  State<_TabIcon> createState() => _TabIconState();
}

class _TabIconState extends State<_TabIcon>
    with SingleTickerProviderStateMixin {
  /// Controller value is the pop progress (0 = rest); the headroom lets the
  /// [MotionSpec.pop] spring's ~20% overshoot breathe without being clipped.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: MotionSpec.pop.duration,
    upperBound: 1.25,
    // Reduce Motion is resolved in didChangeDependencies, not shortened here.
    animationBehavior: AnimationBehavior.preserve,
  );

  late final Tween<double> _scale =
      Tween<double>(begin: 1, end: 1 + _TabIcon.pop);

  bool _reduceMotion = false;
  MotionScheme _scheme = MotionScheme.expressive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = AppMotionConfig.of(context);
    _scheme = motion.scheme;
    _reduceMotion = motion.reduceMotion;
    if (_reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void didUpdateWidget(_TabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected || _reduceMotion) return;
    (widget.selected ? MotionSpec.pop : MotionSpec.toggle).drive(
      _ctrl,
      target: widget.selected ? 1 : 0,
      scheme: _scheme,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _ctrl,
      child: Icon(
        widget.icon,
        color: widget.selected ? p.accentText : p.secondary,
      ),
      builder: (context, child) => Transform.scale(
        scale: _scale.transform(_ctrl.value),
        transformHitTests: false,
        child: child,
      ),
    );
  }
}

/// Shared header row: screen title + gym switcher, rendered above tab
/// content. The switcher is a ≥44pt tap target (DropdownButton rows pad
/// internally); the header keeps 20–24px screen padding.
class ShellHeader extends ConsumerWidget {
  const ShellHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screen, AppSpace.md, AppSpace.screen, AppSpace.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppType.title.copyWith(color: p.text))),
          const SizedBox(height: 44, child: Center(child: GymSwitcher())),
        ],
      ),
    );
  }
}

/// Wraps a raw tab body with the shared header + safe area.
class _TabPage extends StatelessWidget {
  const _TabPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShellHeader(title: title),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Members tab: passes the canonical gym id into the screen.
class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymId = ref.watch(selectedGymIdProvider);
    return _TabPage(
      title: 'Members',
      child: MembersScreen(gymId: gymId),
    );
  }
}

/// Plans tab: passes the canonical gym id into the screen.
class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymId = ref.watch(selectedGymIdProvider);
    return _TabPage(
      title: 'Plans',
      child: PlansScreen(gymId: gymId),
    );
  }
}
