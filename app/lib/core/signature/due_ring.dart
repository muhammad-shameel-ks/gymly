/// `DueRing` — Gymly's one visual signature.
///
/// A thin ring that encodes **how much of the current subscription period has
/// elapsed**: empty the day a member renews, full on the expiry date. It makes
/// "who is running out" legible at a glance in Member rows, the Member detail
/// header and any list that triages dues. It is informative, never decoration —
/// if a surface has no subscription period to show, it does not get a ring.
///
/// Contract (other slices code against this exactly):
///
/// - **Track** is `palette.border`; the **sweep** is the bucket colour
///   (`palette.error` overdue · `palette.warning` due soon · `palette.success`
///   active). Both are theme colours — never a hex.
/// - **No subscription** (`progress == null`): the ring paints full and muted
///   (`palette.secondary` at ~0.35 alpha) and says so — it never fakes a bucket
///   the member does not have.
/// - Ordering: **12 o'clock, clockwise**; the arc is clamped to 0..1.
/// - **Once per appear**: it fills empty → `progress` with [MotionSpec.fill]
///   (300 ms in, 175 ms back out) and never loops. A renewal moves `progress`
///   back down (reset) and the same transition plays — the app's one hero
///   moment, ≤ 500 ms, never repeated on rebuild.
/// - **Reduce Motion** (`AppMotionConfig.of(context).reduceMotion`): no fill at
///   all — the final value is painted on the first frame.
/// - **Cheap**: one [CustomPaint], one [BucketRingPainter.paint] pass, no
///   `saveLayer`, no blur, no shadow; repaints are driven by the controller's
///   ticker, so a fill allocates nothing per frame.
/// - **Screen readers**: the ring always carries its own label
///   ("63% of the membership period used" / "No subscription yet").
///
/// ```dart
/// DueRing(
///   progress: periodProgress(member.current),
///   bucket: member.bucket,
///   child: InitialsAvatar(member.name),
/// )
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/members/models/member.dart' show DueBucket, Subscription;
import '../motion/app_motion_config.dart';
import '../motion/motion_spec.dart';
import '../theme/app_palette.dart';

/// Elapsed fraction of [s]'s period at [today]: `0.0` the day it starts,
/// `1.0` on the expiry date.
///
/// - Returns **`null`** when [s] is null (no subscription yet) — [DueRing] then
///   paints the full muted ring, i.e. the painted fraction is `1.0` with no
///   bucket colour and no "100% used" claim.
/// - Guarded and clamped: `expiry == start` (or expiry before start, bad data)
///   → `1.0`; a date before `start` → `0.0`; past expiry → `1.0`.
/// - Day granularity, local dates, matching `Subscription.daysToExpiry`.
///
/// Callers that need a number when there is no period:
/// `periodProgress(s) ?? 1.0`.
double? periodProgress(Subscription? s, {DateTime? today}) {
  if (s == null) return null;
  final start = _day(s.startDate);
  final expiry = _day(s.expiryDate);
  final span = expiry.difference(start).inDays;
  // Zero or negative span: nothing left to run, so the ring is full.
  if (span <= 0) return 1.0;
  final elapsed = _day(today ?? DateTime.now()).difference(start).inDays;
  return (elapsed / span).clamp(0.0, 1.0);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The app's signature ring. See the library doc for the full contract.
class DueRing extends StatelessWidget {
  const DueRing({
    super.key,
    required this.progress,
    required this.bucket,
    this.size = 48,
    this.strokeWidth = 3,
    this.child,
  });

  /// Fraction of the period used: `0.0` just renewed → `1.0` at expiry
  /// (clamped). `null` = no subscription yet → full muted ring, and [bucket] is
  /// ignored. Use [periodProgress] to compute it.
  final double? progress;

  /// Triage bucket; picks the sweep colour (overdue → `error`, due soon →
  /// `warning`, active → `success`).
  final DueBucket bucket;

  /// Outer diameter of the ring. Give it the avatar's size plus the stroke.
  final double size;

  /// Ring thickness. 3 is the app default; 2 for dense rows.
  final double strokeWidth;

  /// Avatar / initials / icon centred inside the ring; null = bare ring.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticsLabel(progress),
      child: _DueRingFill(
        progress: progress,
        bucket: bucket,
        size: size,
        strokeWidth: strokeWidth,
        child: child,
      ),
    );
  }
}

/// "63% of the membership period used" / "No subscription yet".
String _semanticsLabel(double? progress) {
  if (progress == null) return 'No subscription yet';
  final percent = (progress.isFinite ? progress : 1.0).clamp(0.0, 1.0) * 100;
  return '${percent.round()}% of the membership period used';
}

/// Owns the fill animation; [DueRing] stays a `StatelessWidget`.
class _DueRingFill extends StatefulWidget {
  const _DueRingFill({
    required this.progress,
    required this.bucket,
    required this.size,
    required this.strokeWidth,
    this.child,
  });

  final double? progress;
  final DueBucket bucket;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  State<_DueRingFill> createState() => _DueRingFillState();
}

class _DueRingFillState extends State<_DueRingFill>
    with SingleTickerProviderStateMixin {
  /// Controller value *is* the painted fraction (0..1), so the painter reads it
  /// straight off the ticker: no widget rebuild per frame.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: MotionSpec.fill.duration,
    // The fill is gated on AppMotionConfig below, not by the framework's
    // blanket duration shortening.
    animationBehavior: AnimationBehavior.preserve,
  );

  bool _reduceMotion = false;
  MotionScheme _scheme = MotionScheme.expressive;
  bool _started = false;

  /// Progress actually painted: no subscription reads as a full ring.
  double get _target => (widget.progress ?? 1.0).clamp(0.0, 1.0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = AppMotionConfig.of(context);
    _scheme = motion.scheme;

    if (motion.reduceMotion) {
      _reduceMotion = true;
      _started = true;
      _ctrl.stop();
      _ctrl.value = _target; // paint the final value immediately
      return;
    }

    _reduceMotion = false;
    if (_started) return; // never replay an entrance on rebuild / theme change
    _started = true;
    _ctrl.value = 0;
    _fill(_target);
  }

  @override
  void didUpdateWidget(_DueRingFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == oldWidget.progress) return;
    if (_reduceMotion) {
      _ctrl.value = _target;
      return;
    }
    // Renewal: progress drops to ~0 and the ring re-fills — same transition.
    _fill(_target);
  }

  void _fill(double target) {
    MotionSpec.fill.drive(
      _ctrl,
      target: target,
      scheme: _scheme,
      // Leaving the ring (a reset) is the cheaper 175 ms budget; a fill takes
      // the full 300 ms. Springs carry the direction themselves.
      duration: _scheme == MotionScheme.standard && target < _ctrl.value
          ? MotionSpec.fill.reverse
          : null,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final noSubscription = widget.progress == null;
    final sweepColor = noSubscription
        ? palette.secondary.withValues(alpha: 0.35)
        : _bucketColor(palette, widget.bucket);

    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: BucketRingPainter(
          progress: _target,
          bucket: widget.bucket,
          trackColor: palette.border,
          sweepColor: sweepColor,
          strokeWidth: widget.strokeWidth,
          animation: _ctrl,
        ),
        child: widget.child == null ? null : Center(child: widget.child),
      ),
    );
  }
}

Color _bucketColor(AppPalette palette, DueBucket bucket) => switch (bucket) {
      DueBucket.overdue => palette.error,
      DueBucket.dueSoon => palette.warning,
      DueBucket.active => palette.success,
    };

/// Paints a [DueRing]: border-coloured track + elapsed sweep from 12 o'clock.
///
/// Public so a surface that owns its own canvas (a chart, a custom header) can
/// draw the same motif. Pass [animation] to let a controller's ticker drive the
/// sweep; without it the arc is drawn at [progress].
class BucketRingPainter extends CustomPainter {
  BucketRingPainter({
    required this.progress,
    required this.bucket,
    required this.trackColor,
    required this.sweepColor,
    required this.strokeWidth,
    this.animation,
  })  : _track = Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
        _sweep = Paint()
          ..color = sweepColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
        super(repaint: animation);

  /// Painted fraction (0..1) used when [animation] is null.
  final double progress;

  /// Bucket the sweep colour came from — carried so [shouldRepaint] can see it.
  final DueBucket bucket;

  /// Track colour, `palette.border`.
  final Color trackColor;

  /// Sweep colour, resolved by the caller (bucket colour, or muted for none).
  final Color sweepColor;

  final double strokeWidth;

  /// Drives the sweep while it settles; null paints [progress] directly.
  final Animation<double>? animation;

  // Built once per painter instance (i.e. per widget build), never per frame.
  final Paint _track;
  final Paint _sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    canvas.drawCircle(center, radius, _track);

    final used = (animation?.value ?? progress).clamp(0.0, 1.0);
    if (used <= 0) return; // a round cap would otherwise leave a dot
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12 o'clock
      2 * math.pi * used, // clockwise
      false,
      _sweep,
    );
  }

  @override
  bool shouldRepaint(BucketRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.bucket != bucket ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.sweepColor != sweepColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
