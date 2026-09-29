/// `StaggeredEntrance` / `RiseIn` — the one entrance animation.
///
/// **Communicates:** "this content arrived, in this order" — a short rise + fade
/// per child, ~40 ms behind the previous one. It is an entrance, never an
/// ambient loop: nothing here animates on idle, on rebuild, or on data change.
///
/// **Budget:** rise + fade over [AppMotion.appear] (250 ms) with
/// [AppMotion.stagger] 40 ms between indices; the delay for index `i` is
/// `min(i, 12) * 40 ms`, so a long list cannot delay its tail forever. One
/// entrance per screen visit, and a route push *is* a new visit: the animation
/// is created in `initState` and the play latches on the first frame, so a hot
/// rebuild, a provider emission, or a `setState` reuses the finished value and
/// never replays.
///
/// **Reduce Motion:** the delay, the rise and the stagger are dropped; children
/// cross-fade in place over [AppMotion.crossFade], opacity only.
///
/// **Scheduling:** the stagger delay is a cancellable `Timer` that is cancelled
/// in `dispose` — an entrance can never fire into a disposed element after the
/// screen is popped mid-stagger.
///
/// Note: an item of a `ListView` that is scrolled far enough out is disposed and
/// rebuilt on the way back, and that is a fresh mount — it will play again. Keep
/// staggered indices inside a screenful (that is what the effect is for) or use
/// [StaggeredEntrance] around the first screenful only.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_motion_config.dart';
import 'motion_spec.dart';

/// Rise + fade entrance for one child, delayed by [index].
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
    this.rise = 12,
    this.duration,
    this.curve,
  });

  final Widget child;

  /// Position in the entrance order; drives the stagger delay.
  final int index;

  /// Explicit delay, overriding the index-based stagger.
  final Duration? delay;

  /// Vertical rise distance in logical px (dropped under Reduce Motion).
  final double rise;

  /// Entrance duration; defaults to [MotionSpec.appear].
  final Duration? duration;

  /// Entrance curve (standard scheme); defaults to [MotionSpec.appear].
  final Curve? curve;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;

  /// Latched on the first frame: the entrance plays once per State, i.e. once
  /// per screen visit. Rebuilds reuse this State and never reset it.
  bool _played = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    final spec = MotionSpec.appear;
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration ?? spec.duration,
      animationBehavior: AnimationBehavior.preserve,
    );
    final curve = CurvedAnimation(
      parent: _ctrl,
      curve: widget.curve ?? spec.curve,
      reverseCurve: (widget.curve ?? spec.curve).flipped,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.rise),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotionConfig.of(context).reduceMotion;
    _schedule();
  }

  void _schedule() {
    if (_played) return;
    _played = true;
    if (_reduceMotion) {
      _ctrl.forward();
      return;
    }
    final delay = widget.delay ?? _indexDelay();
    if (delay <= Duration.zero) {
      _ctrl.forward();
      return;
    }
    _delayTimer = Timer(delay, _play);
  }

  Duration _indexDelay() {
    final index = widget.index.clamp(0, 12);
    return Duration(milliseconds: index * AppMotion.stagger.inMilliseconds);
  }

  void _play() {
    _delayTimer = null;
    if (!mounted) return;
    _ctrl.forward();
  }

  @override
  void dispose() {
    // Cancel the pending stagger so nothing can fire after the element is gone.
    _delayTimer?.cancel();
    _delayTimer = null;
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final opacity = _fade.value.clamp(0.0, 1.0);
        if (_reduceMotion) return Opacity(opacity: opacity, child: child);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: _slide.value, child: child),
        );
      },
    );
  }
}

/// Single-child entrance with no stagger delay — the common case for a screen
/// body that is not a list. Same budget, same once-per-visit latch and same
/// Reduce Motion cross-fade as [StaggeredEntrance].
class RiseIn extends StatelessWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.rise = 12,
    this.duration,
    this.curve,
  });

  final Widget child;
  final double rise;
  final Duration? duration;
  final Curve? curve;

  @override
  Widget build(BuildContext context) {
    return StaggeredEntrance(
      delay: Duration.zero,
      rise: rise,
      duration: duration,
      curve: curve,
      child: child,
    );
  }
}
