/// `TapScale` — the one press primitive: scale + surface overlay + haptic.
///
/// **Communicates:** "your finger landed, this will respond" (press-down) and
/// "done" (release), with a haptic that confirms the same event.
///
/// **Budget:** press-down and release are springs ([AppMotion.springTap],
/// [AppMotion.springTapRelease]) that settle inside the 100–150 ms tap budget.
/// A spring, not a tween, because the release inherits the press's velocity —
/// a tap snapped mid-gesture always looks like the same object.
///
/// **Reduce Motion:** no scale. Press feedback becomes opacity only — the
/// [pressOverlay] (cards/rows) or a dim of the child ([dimOpacity]) — so a press
/// is still visible without any translation.
///
/// **Gestures:** with no [onTap]/[onLongPress] this wraps the child in a
/// [Listener], which does not enter the gesture arena — an inner [InkWell] or
/// [GestureDetector] keeps working and still gets the press animation. Supplying
/// [onTap] switches to a [GestureDetector] that owns the gesture (do not also
/// wire the child). Press state is released if the pointer travels past
/// `kTouchSlop`, so starting a scroll never leaves a card stuck small.
///
/// Hit testing is not transformed (`transformHitTests: false`), and when this
/// widget owns the gesture ([expandTapTarget], the default) it keeps a
/// ≥ [minTapTarget] box, so the 44/48 pt target is never shrunk by the 0.97
/// press scale. Wrappers that only add press feedback to a child's own gestures
/// leave sizing to that child.
library;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_motion_config.dart';
import 'haptics.dart';
import 'motion_spec.dart';

/// Press-motion wrapper. See the library doc for the contract.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.dimOpacity = 0.72,
    this.haptic = HapticStrength.light,
    this.enableHaptic = true,
    this.enabled = true,
    this.expandTapTarget = true,
    this.pressOverlay,
    this.pressOverlayRadius,
    this.semanticsLabel,
  });

  final Widget child;

  /// Tap handler. When null (and [onLongPress] is null) the child keeps its own
  /// gesture handling and only the press feedback is added.
  final VoidCallback? onTap;

  /// Optional long-press; fires [haptic] before the callback.
  final VoidCallback? onLongPress;

  /// Pressed scale. ~0.97 for standalone controls, ~0.985 for full-bleed cards.
  final double scale;

  /// Child opacity at full press when there is no [pressOverlay]
  /// (Reduce Motion feedback).
  final double dimOpacity;

  /// Haptic weight for a confirmed tap.
  final HapticStrength haptic;

  /// Set false when the parent already supplied haptics.
  final bool enableHaptic;

  /// When false the widget is inert (no press feedback, no haptic).
  final bool enabled;

  /// Keeps a ≥ [minTapTarget] hit box when the widget owns the gesture.
  final bool expandTapTarget;

  /// Colour painted over the child while pressed, e.g. a 6% white on a card.
  /// Preferred over dimming for opaque surfaces (text stays crisp).
  final Color? pressOverlay;

  /// Clip for [pressOverlay]; pass the surface's radius.
  final BorderRadius? pressOverlayRadius;

  /// Semantics label when this wrapper owns the tap.
  final String? semanticsLabel;

  /// Minimum square tap target in logical px (DESIGN.md §4).
  static const double minTapTarget = 44;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  /// Controller value is the 0 → 1 press progress; the ±0.15 headroom lets the
  /// release spring breathe past rest without the scale being clipped.
  late final AnimationController _ctrl;
  late Tween<double> _scaleTween;
  late Tween<double> _dimTween;
  bool _pressed = false;
  bool _reduceMotion = false;
  Offset? _downPosition;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.tap,
      lowerBound: -0.15,
      upperBound: 1.15,
      // Reduce Motion is resolved here, in AppMotionConfig; opt out of the
      // framework's blanket duration shortening so the cross-fade the design
      // asks for is what actually runs.
      animationBehavior: AnimationBehavior.preserve,
    );
    _scaleTween = Tween<double>(begin: 1, end: widget.scale);
    _dimTween = Tween<double>(begin: 1, end: widget.dimOpacity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AppMotionConfig.of(context).reduceMotion;
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _ctrl.stop();
      _ctrl.value = 0;
      _pressed = false;
      _downPosition = null;
    }
  }

  @override
  void didUpdateWidget(TapScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scale != oldWidget.scale) {
      _scaleTween = Tween<double>(begin: 1, end: widget.scale);
    }
    if (widget.dimOpacity != oldWidget.dimOpacity) {
      _dimTween = Tween<double>(begin: 1, end: widget.dimOpacity);
    }
    if (!widget.enabled) _release();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _drive(double target) {
    if (_reduceMotion) {
      _ctrl.animateTo(
        target,
        duration: AppMotion.tap,
        curve: AppMotion.standardDecelerate,
      );
      return;
    }
    final spec = target > 0.5 ? MotionSpec.tap : MotionSpec.tapRelease;
    _ctrl.animateWith(spec.simulation(_ctrl.value, target));
  }

  void _press() {
    if (!widget.enabled || _pressed) return;
    setState(() => _pressed = true);
    _drive(1);
  }

  void _release() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _drive(0);
  }

  void _confirmTap() {
    if (widget.enableHaptic) Haptics.impact(strength: widget.haptic);
    widget.onTap?.call();
  }

  void _confirmLongPress() {
    if (widget.enableHaptic) Haptics.impact(strength: widget.haptic);
    widget.onLongPress?.call();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _downPosition = event.position;
    _press();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pressed) return;
    final origin = _downPosition;
    if (origin == null) return;
    // A drag is not a press: release as soon as the pointer leaves the slop.
    if ((event.position - origin).distance > kTouchSlop) _release();
  }

  void _handlePointerEnd() {
    _downPosition = null;
    _release();
  }

  bool get _ownsGesture => widget.onTap != null || widget.onLongPress != null;

  Widget _pressFeedback() {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final value = _ctrl.value;
        final overlay = widget.pressOverlay;
        if (_reduceMotion) {
          if (overlay != null) return _overlaid(child!, value, overlay);
          return Opacity(
            opacity: _dimTween.transform(value).clamp(0.0, 1.0),
            child: child,
          );
        }
        final scaled = Transform.scale(
          scale: _scaleTween.transform(value),
          transformHitTests: false,
          child: child,
        );
        if (overlay == null) return scaled;
        return _overlaid(scaled, value, overlay);
      },
    );
  }

  Widget _overlaid(Widget child, double progress, Color overlay) {
    final stack = Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: ColoredBox(color: overlay),
            ),
          ),
        ),
      ],
    );
    final radius = widget.pressOverlayRadius;
    if (radius == null || radius == BorderRadius.zero) return stack;
    return ClipRRect(borderRadius: radius, child: stack);
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _pressFeedback();
    final Widget target;
    if (_ownsGesture) {
      final gestured = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap == null ? null : _confirmTap,
        onLongPress: widget.onLongPress == null ? null : _confirmLongPress,
        child: feedback,
      );
      // A label is only added when asked for: the GestureDetector already
      // publishes the tap action, and wrapping a card that contains its own
      // buttons would add a second focus stop in front of them.
      target = widget.semanticsLabel == null
          ? gestured
          : Semantics(
              button: true,
              enabled: widget.enabled,
              label: widget.semanticsLabel,
              child: gestured,
            );
    } else {
      target = Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: (_) => _handlePointerEnd(),
        onPointerCancel: (_) => _handlePointerEnd(),
        child: feedback,
      );
    }
    if (!widget.expandTapTarget || !_ownsGesture) return target;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TapScale.minTapTarget,
        minHeight: TapScale.minTapTarget,
      ),
      child: target,
    );
  }
}
