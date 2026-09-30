/// `AnimatedCounter` / `AnimatedAmount` — numbers that settle, not spin.
///
/// **Communicates:** "this value changed" — a count-up rolls from the previous
/// value to the new one instead of swapping, so a payment or a refreshed feed is
/// legible as a change. It replaces stale digits in place; it never draws
/// attention to itself, so it is never used to *decorate* a static number.
///
/// **Budget:** [MotionSpec.count] — 280 ms, critically damped, so the number
/// arrives without overshooting past the real value. Interrupted mid-roll, the
/// new value animates from the digits currently on screen.
///
/// **No layout shift:** the text requests tabular figures, so every digit has
/// the same advance and the label does not jitter while rolling. Crossing a
/// digit-count boundary (₹999 → ₹1000) still changes the width once — a static
/// change, so callers that must be pinned can wrap the widget in a `SizedBox`.
///
/// **Reduce Motion:** the value is set immediately; no roll, no fade.
library;

import 'package:flutter/material.dart';

import 'app_motion_config.dart';
import 'motion_spec.dart';

/// Integer count-up. Also the primitive a badge/tab count should use.
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.initialValue = 0,
    this.duration,
    this.animate = true,
    this.tabularFigures = true,
    this.textAlign,
  });

  /// Target value.
  final int value;

  /// Text style; the colour is the caller's (tokens carry no colour).
  final TextStyle? style;

  /// Value shown on the first frame, and the value it rolls up from.
  final int initialValue;

  /// Overrides [MotionSpec.count.duration] for the standard scheme.
  final Duration? duration;

  /// `false` renders the target immediately (no roll on first paint e.g. for
  /// a value restored from cache).
  final bool animate;

  /// Requests `tnum` so digits do not change the label width while rolling.
  final bool tabularFigures;

  final TextAlign? textAlign;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late IntTween _tween;
  late TextStyle? _style;
  MotionScheme _scheme = MotionScheme.expressive;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration ?? MotionSpec.count.duration,
      value: widget.animate ? 0 : 1,
      animationBehavior: AnimationBehavior.preserve,
    );
    _ctrl.addStatusListener(_onStatus);
    _tween = IntTween(begin: widget.initialValue, end: widget.value);
    _style = _withFigures(widget.style);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheme = AppMotionConfig.of(context).scheme;
    if (_started) return;
    _started = true;
    _animateToTarget();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style != oldWidget.style) {
      _style = _withFigures(widget.style);
    }
    if (widget.value != oldWidget.value) {
      // Roll from what is on screen, not from the old target.
      _tween = IntTween(begin: _displayed, end: widget.value);
      _ctrl.value = 0;
      _animateToTarget();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _ctrl.value = 1;
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  int get _displayed => _tween.transform(_ctrl.value.clamp(0.0, 1.0));

  void _animateToTarget() {
    if (!widget.animate || AppMotionConfig.reduceMotionOf(context)) {
      _ctrl.value = 1;
      return;
    }
    MotionSpec.count.drive(
      _ctrl,
      target: 1,
      scheme: _scheme,
      duration: widget.duration,
    );
  }

  TextStyle? _withFigures(TextStyle? style) {
    if (!widget.tabularFigures) return style;
    return (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Text(
        '$_displayed',
        style: _style,
        textAlign: widget.textAlign,
        softWrap: false,
      ),
    );
  }
}

/// Currency count-up: [AnimatedCounter] with the app's `₹` label convention.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({
    super.key,
    required this.amount,
    this.style,
    this.symbol = '₹',
    this.initialAmount = 0,
    this.duration,
    this.animate = true,
    this.tabularFigures = true,
    this.textAlign,
    this.formatter,
  });

  /// Target amount in ₹.
  final double amount;

  final TextStyle? style;

  /// Currency symbol; `'₹'` for every amount in this app.
  final String symbol;

  final double initialAmount;
  final Duration? duration;
  final bool animate;
  final bool tabularFigures;
  final TextAlign? textAlign;

  /// Overrides the default label. Default renders whole targets as `₹3333`
  /// and fractional targets as `₹499.50`, matching `Plan.amountLabel`, but
  /// **fixed to the target's precision** so the rolling label never changes
  /// format mid-roll.
  final String Function(double value)? formatter;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Tween<double> _tween;
  late TextStyle? _style;
  MotionScheme _scheme = MotionScheme.expressive;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration ?? MotionSpec.count.duration,
      value: widget.animate ? 0 : 1,
      animationBehavior: AnimationBehavior.preserve,
    );
    _ctrl.addStatusListener(_onStatus);
    _tween = Tween<double>(begin: widget.initialAmount, end: widget.amount);
    _style = _withFigures(widget.style);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheme = AppMotionConfig.of(context).scheme;
    if (_started) return;
    _started = true;
    _animateToTarget();
  }

  @override
  void didUpdateWidget(AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style != oldWidget.style) {
      _style = _withFigures(widget.style);
    }
    if (widget.amount != oldWidget.amount) {
      _tween = Tween<double>(begin: _displayed, end: widget.amount);
      _ctrl.value = 0;
      _animateToTarget();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _ctrl.value = 1;
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  double get _displayed => _tween.transform(_ctrl.value.clamp(0.0, 1.0));

  void _animateToTarget() {
    if (!widget.animate || AppMotionConfig.reduceMotionOf(context)) {
      _ctrl.value = 1;
      return;
    }
    MotionSpec.count.drive(
      _ctrl,
      target: 1,
      scheme: _scheme,
      duration: widget.duration,
    );
  }

  TextStyle? _withFigures(TextStyle? style) {
    if (!widget.tabularFigures) return style;
    return (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// `₹3333` for whole targets, `₹499.50` otherwise — decided from the target,
  /// so the rolling label keeps one shape.
  String _label(double value) {
    final custom = widget.formatter;
    if (custom != null) return custom(value);
    final whole = widget.amount.remainder(1) == 0;
    return whole
        ? '${widget.symbol}${value.round()}'
        : '${widget.symbol}${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Text(
        _label(_displayed),
        style: _style,
        textAlign: widget.textAlign,
        softWrap: false,
      ),
    );
  }
}
