/// Launch handoff: the branded [LaunchSplash] over the live app, shown **once**
/// per app process and gone for good.
///
/// Wired in `main.dart` through `MaterialApp.router`'s `builder`, so it sits
/// inside `Theme`/`Directionality`/`MediaQuery` (it inherits the theme tokens,
/// never a hardcoded colour), *above* the router's `Navigator` — and therefore
/// survives route changes instead of re-mounting per visit.
///
/// **Timing.** The router's first frame already paints the destination (login or
/// the tab shell) *underneath* the surface: the fade starts on the frame the app
/// reaches the screen and never holds a frame back. There is deliberately no
/// artificial hold — the OS window is painted the launch brand colour for the
/// whole engine start (Android resolves exactly the token; iOS uses the system
/// background, which matches it in light and is near black in dark), so the brand
/// is already up for as long as the cold start takes and time-to-first-frame is
/// untouched.
///
/// **Once only.** The controller is created in [initState] and latches on the
/// first frame; when the fade completes the surface is dropped from the tree
/// (`_done`), so a rebuild, a provider emission or a route change cannot replay
/// it. The steady state is the app in a bare stack: no surface, no animation,
/// no rebuild and no gesture interception.
///
/// **Motion.** Opacity only, through the motion layer: [MotionSpec.appear] in the
/// standard scheme (a launch handoff is not gesture-linked, so it must land on a
/// known frame — a spring's settle is not deterministic), or
/// [MotionSpec.crossFade] under Reduce Motion. Read in
/// [didChangeDependencies], never [initState]. The ticker is
/// [AnimationBehavior.preserve] so the cross-fade still plays while the OS
/// Reduce Motion switch is on.
library;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import 'launch_splash.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  /// The live app — the router's `Navigator`, painted from the first frame.
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  /// 0 = the launch surface owns the screen, 1 = the app does.
  late final AnimationController _progress;

  bool _reduceMotion = false;

  /// Latched when the fade finishes; the surface is then removed from the tree.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: MotionSpec.appear.duration,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_onStatus);
    WidgetsBinding.instance.addPostFrameCallback(_handOver);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotionConfig.of(context).reduceMotion;
  }

  void _handOver(Duration _) {
    if (!mounted || _done) return;
    final spec = _reduceMotion ? MotionSpec.crossFade : MotionSpec.appear;
    spec.drive(
      _progress,
      target: 1,
      scheme: MotionScheme.standard,
      duration: spec.duration,
    );
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _done || !mounted) return;
    setState(() => _done = true);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The app keeps slot 0 of the stack for the whole process, so dropping the
    // surface never re-parents the router's Navigator (which would rebuild the
    // app and lose every tab's state). `Clip.none` keeps the wrapper invisible:
    // the app child still gets the tight, full-screen constraints the root view
    // gave it, and nothing it paints is newly clipped.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(child: widget.child),
        if (!_done)
          // `AbsorbPointer` keeps taps off controls the user cannot see yet, for
          // the length of the fade only.
          Positioned.fill(
            child: AbsorbPointer(
              child: LaunchSplash(
                progress: _progress,
                reduceMotion: _reduceMotion,
              ),
            ),
          ),
      ],
    );
  }
}
