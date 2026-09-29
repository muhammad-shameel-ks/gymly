/// `TabTransition` — the bottom-tab shared-axis entrance.
///
/// **Communicates:** *which way you moved across the bar.* Switching tabs is a
/// horizontal move, so the arriving tab's content enters from the side you
/// travelled towards and fades in: Dues → Members (higher index) enters from the
/// trailing edge, Members → Dues (lower index) from the leading edge. Direction
/// comes from the **previous vs the new index**, so a jump across the bar
/// (Dues → Plans) still reads as one lateral move rather than a cut, and it is
/// mirrored in RTL (where a higher index sits further left) exactly as
/// `AppSlideFadeTransitionsBuilder` mirrors a screen push.
///
/// **Budget:** [MotionSpec.appear] — 250 ms (the DESIGN.md §5 200–300 ms band for
/// this class), slide ~8% of width + fade 0 → 1 on the M3 `emphasizedDecelerate`
/// curve. Like a route transition this class is deterministic, not
/// gesture-linked, so it uses the token curve rather than a spring. The curve is
/// monotonic, so the entrance lands on exactly `Offset.zero` / opacity 1: the
/// content never rests transformed.
///
/// **In place, never a remount.** The wrapper only ever *transforms* the widget
/// it is handed — it never swaps children: one child, one element, updated in
/// place. Use it around `StatefulNavigationShell`: the shell owns one `Navigator`
/// per branch behind `GlobalKey`s, so a switcher (or a re-key) that mounts a
/// second copy would duplicate those keys and/or dispose live branch navigators,
/// losing tab state and asserting. Here the shell's element, its keys and its
/// scroll positions are untouched: `SlideTransition`/`FadeTransition` are
/// paint-level only, constraints pass through unchanged (no layout), and the
/// shell is the `child` they hand down — never rebuilt on a tick, only the two
/// transition render objects are.
///
/// **Once per change:** the entrance fires from [didUpdateWidget] and only when
/// `index` actually changed — a rebuild with the same index (provider emission,
/// `setState`, theme change, a branch pushing a route) reuses the running or
/// finished controller and never replays. There is no `Future.delayed` and no
/// ambient loop: the controller runs once and stops.
///
/// **Reduce Motion:** resolved in `didChangeDependencies` via [AppMotionConfig];
/// the slide is dropped and the change cross-fades in place over
/// [MotionSpec.crossFade] (160 ms, opacity only). If Reduce Motion is switched on
/// mid-entrance the animation lands on the settled state instead of finishing.
///
/// ```dart
/// // One wrapper around the shell's body — the bar itself does not move.
/// body: TabTransition(index: shell.currentIndex, child: shell),
/// ```
library;

import 'package:flutter/material.dart';

import 'app_motion_config.dart';
import 'motion_spec.dart';

/// Shared-axis entrance for a bottom-tab body: slide from the direction of
/// travel + fade, in place.
class TabTransition extends StatefulWidget {
  const TabTransition({
    super.key,
    required this.index,
    required this.child,
    this.fraction = 0.08,
  });

  /// The active destination (e.g. `StatefulNavigationShell.currentIndex`).
  /// Changing it plays one entrance; the direction is old → new.
  final int index;

  /// The content being switched. It is transformed, never replaced, so its
  /// element (and everything under it: scroll offsets, text fields, branch
  /// navigators) survives the animation.
  final Widget? child;

  /// Slide distance as a fraction of the body's width (6–10% is the readable
  /// band; more reads as a carousel, less as a jolt).
  final double fraction;

  @override
  State<TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Curve applied to the linear controller. Created once in [initState] (a
  /// [CurvedAnimation] must not be recreated per rebuild — it listens to its
  /// parent) and re-pointed at the scheme's curve per play.
  late final CurvedAnimation _curve;

  /// Inert at rest (`begin == end`): until a change happens, nothing is
  /// transformed whatever the controller reads.
  late final Tween<Offset> _shift;

  /// The slide for the current direction. A fractional translation, so the
  /// distance is a fraction of the body's width without reading `MediaQuery`.
  late final Animation<Offset> _slide;

  /// Travel direction of the current entrance: `1` for a higher index (enters
  /// from the trailing edge), `-1` for a lower one. Stored before the animation
  /// starts so the run never reads a half-updated index.
  double _direction = 1.0;

  /// Mirrors the slide in RTL, where a higher index sits further left — the
  /// same rule `AppSlideFadeTransitionsBuilder` applies to a screen push.
  bool _rtl = false;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionSpec.appear.duration,
      // Reduce Motion is resolved in didChangeDependencies; never shorten the
      // controller here.
      animationBehavior: AnimationBehavior.preserve,
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: MotionSpec.appear.curve);
    _shift = Tween<Offset>(begin: Offset.zero, end: Offset.zero);
    _slide = _shift.animate(_curve);
    // The app opens on a tab that is already there: mounting plays nothing.
    _ctrl.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rtl = Directionality.of(context) == TextDirection.rtl;
    final reduceMotion = AppMotionConfig.of(context).reduceMotion;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      // Switched on (possibly mid-entrance): land settled — opacity only from
      // here, nothing left translated.
      _ctrl.stop();
      _ctrl.value = 1;
    }
  }

  @override
  void didUpdateWidget(TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    // One entrance per change: a rebuild with the same index never replays.
    if (widget.index == oldWidget.index) return;
    _direction = widget.index > oldWidget.index ? 1.0 : -1.0;
    _play();
  }

  void _play() {
    final spec = _reduceMotion ? MotionSpec.crossFade : MotionSpec.appear;
    _ctrl.duration = spec.duration;
    _curve.curve = spec.curve;
    // Under Reduce Motion the tween is inert: the fade carries the change.
    final direction = _reduceMotion ? 0.0 : _direction * (_rtl ? -1.0 : 1.0);
    _shift.begin = Offset(direction * widget.fraction, 0);
    // Restart rather than continue: the tab that is entering is the one that
    // must slide in, even when the previous entrance was interrupted.
    _ctrl.value = 0;
    _ctrl.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (child == null) return const SizedBox.shrink();
    // No per-frame work here: both transitions listen to the animations
    // themselves, so this build runs per shell rebuild, not per frame.
    if (_reduceMotion) return FadeTransition(opacity: _curve, child: child);
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(position: _slide, child: child),
    );
  }
}
