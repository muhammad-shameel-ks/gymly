/// `AnimatedCheck` / `AnimatedStatusDot` — the two small state-change signals.
///
/// Both answer the same question — *"did this just change?"* — in the two places
/// the app needs it: selection (chips, plans, gym switcher rows) and due-bucket
/// status (Overdue / Due soon / Active dots).
///
/// **AnimatedCheck** draws the tick in (a stroke-level draw, not a fade) and
/// scales it up over [MotionSpec.pop]; deselecting retracts it. The tick is a
/// [PathMetric] extraction, so the stroke stays crisp at any [size] and nothing
/// re-lays out. **Budget:** 200 ms, one overshoot, and the overshoot is one
/// deliberate pop — never repeated, never ambient.
///
/// **AnimatedStatusDot** springs once when its [statusKey] changes: scale
/// `0.6 → 1.0` with a ζ 0.45 overshoot and a halo that fades out. It never
/// animates on rebuild, only on an actual bucket change, which is exactly the
/// product rule for the due feed. **Budget:** [MotionSpec.pop].
///
/// **Reduce Motion:** both snap to their new state — the check appears at full
/// draw, the dot changes colour with no scale or halo. Opacity/colour is the
/// information; the movement was only emphasis.
///
/// Haptics are *not* fired here: these are visual affordances. The control that
/// owns them pairs the change with [Haptics.select] (chips/pickers) or
/// `Haptics.impact` (toggle), so one user action produces exactly one haptic.
library;

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_motion_config.dart';
import 'motion_spec.dart';

/// Tick that draws in / retracts with an optional composed scale.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.selected,
    this.color,
    this.size = 18,
    this.strokeWidth = 2.4,
    this.animate = true,
  });

  /// Selected state; a change drives the animation.
  final bool selected;

  /// Stroke colour; defaults to `context.palette.accentText`.
  final Color? color;

  /// Box size in logical px.
  final double size;

  final double strokeWidth;

  /// `false` (or Reduce Motion) renders the state without animating.
  final bool animate;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Tween<double> _scale;
  late PathMetric _metric;
  late Paint _paint;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionSpec.pop.duration,
      value: widget.selected ? 1 : 0,
      lowerBound: 0,
      upperBound: 1.15,
      animationBehavior: AnimationBehavior.preserve,
    );
    _scale = Tween<double>(begin: 0.8, end: 1);
    _metric = _metricFor(widget.size);
    _paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = widget.strokeWidth;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotionConfig.of(context).reduceMotion;
  }

  @override
  void didUpdateWidget(AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.size != oldWidget.size) _metric = _metricFor(widget.size);
    if (widget.strokeWidth != oldWidget.strokeWidth) {
      _paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = widget.strokeWidth;
    }
    if (widget.selected != oldWidget.selected) {
      if (!widget.animate || _reduceMotion) {
        _ctrl.value = widget.selected ? 1 : 0;
        return;
      }
      MotionSpec.pop.drive(_ctrl, target: widget.selected ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static PathMetric _metricFor(double size) {
    final path = Path()
      ..moveTo(size * 0.22, size * 0.52)
      ..lineTo(size * 0.42, size * 0.72)
      ..lineTo(size * 0.80, size * 0.28);
    return path.computeMetrics().first;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.palette.accentText;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final progress = _ctrl.value.clamp(0.0, 1.0);
        if (progress == 0) return SizedBox.square(dimension: widget.size);
        final tick = CustomPaint(
          size: Size.square(widget.size),
          painter: _CheckPainter(
            metric: _metric,
            progress: progress,
            strokePaint: _paint,
            color: color,
          ),
        );
        if (_reduceMotion) return tick;
        return Transform.scale(
          scale: _scale.transform(_ctrl.value),
          child: tick,
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.metric,
    required this.progress,
    required this.strokePaint,
    required this.color,
  });

  final PathMetric metric;
  final double progress;

  /// Prebuilt stroke paint (colour assigned per paint) — created once in the
  /// State so nothing is allocated per frame except the extracted path.
  final Paint strokePaint;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(drawn, strokePaint..color = color);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.metric != metric ||
      oldDelegate.color != color;
}

/// Due-bucket (or any discrete status) dot that pops when the status changes.
///
/// The footprint is `2 × size` on both axes so the one-shot halo has room; the
/// dot itself is centred in that box. Anything tighter should pass `halo: false`.
class AnimatedStatusDot extends StatefulWidget {
  const AnimatedStatusDot({
    super.key,
    required this.color,
    this.statusKey,
    this.size = 10,
    this.halo = true,
  });

  /// Bucket colour: `palette.error` overdue, `palette.warning` due soon,
  /// `palette.success` active.
  final Color color;

  /// Any value identifying the status (e.g. a due-bucket enum). A change pops
  /// the dot once; a rebuild with an equal value does nothing.
  final Object? statusKey;

  final double size;

  /// One-shot halo ring on change; adds emphasis without a loop.
  final bool halo;

  @override
  State<AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Tween<double> _scale;
  late final Tween<double> _haloOpacity;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionSpec.pop.duration,
      value: 1,
      animationBehavior: AnimationBehavior.preserve,
    );
    _scale = Tween<double>(begin: 0.6, end: 1);
    _haloOpacity = Tween<double>(begin: 0.35, end: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotionConfig.of(context).reduceMotion;
  }

  @override
  void didUpdateWidget(AnimatedStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = widget.statusKey != oldWidget.statusKey;
    if (!changed) return;
    if (_reduceMotion) {
      _ctrl.value = 1;
      return;
    }
    _ctrl.value = 0;
    MotionSpec.pop.drive(_ctrl, target: 1);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox.square(
      dimension: size * 2,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final scale = _reduceMotion
              ? 1.0
              : _scale.transform(_ctrl.value.clamp(0.0, 1.15));
          final halo = widget.halo && !_reduceMotion
              ? _haloOpacity.transform(_ctrl.value.clamp(0.0, 1.0))
              : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (halo > 0)
                Opacity(
                  opacity: halo,
                  child: Container(
                    width: size * 2,
                    height: size * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                    ),
                  ),
                ),
              Transform.scale(
                scale: scale,
                child: SizedBox.square(
                  dimension: size,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
