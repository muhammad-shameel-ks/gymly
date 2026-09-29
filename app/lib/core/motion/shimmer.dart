/// `Shimmer` — loading skeletons that sweep, then stop existing.
///
/// **Communicates:** "data is on its way; this is the shape it will take".
/// The child lays out the real geometry (skeleton boxes matching the eventual
/// card/row), and the sweep is a translating gradient masked over it — so the
/// placeholder reads as a *pending surface*, not as content.
///
/// **Budget:** one continuous sweep, [AppMotion] has no token for it because it
/// is the app's only looping animation and it is bound to a transient loading
/// state, never ambient. The sweep moves a `LinearGradient` by `2 ×` width over
/// 1.4 s using a [GradientTransform] — transform/opacity only, the child's
/// layout is untouched, and the subtree is passed as `child` to [AnimatedBuilder]
/// so it is not rebuilt per frame (only the shader is re-applied at paint).
///
/// **Reduce Motion:** no sweep at all — the child renders as a static skeleton
/// (its own fill colours already read as "not content"), and the controller is
/// stopped rather than merely hidden, so nothing runs behind the scenes.
///
/// Because this is the only loop in the motion layer, it must be scoped to the
/// skeleton subtree and must disappear with it: wrap `ShimmerBox` placeholders,
/// never the whole screen's loaded content.
library;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_motion_config.dart';

/// Sweeping skeleton wrapper. See the library doc for the contract.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1400),
    this.highlightMix = 0.45,
  });

  /// Skeleton subtree (usually a column of [ShimmerBox]es).
  final Widget child;

  /// One full sweep left → right.
  final Duration period;

  /// How far the highlight is mixed from `border` towards `secondary` (0 would
  /// be invisible).
  final double highlightMix;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final _SlidingGradientTransform _slide;
  LinearGradient? _gradient;
  AppPalette? _palette;
  Shader Function(Rect)? _shaderCallback;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.period,
      animationBehavior: AnimationBehavior.preserve,
    );
    _slide = _SlidingGradientTransform(_ctrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One gradient per palette; rebuild it only when the theme actually changes.
    final palette = context.palette;
    if (!identical(_palette, palette) || _gradient == null) {
      _palette = palette;
      _gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          palette.border,
          Color.lerp(palette.border, palette.secondary, widget.highlightMix)!,
          palette.border,
        ],
        stops: const [0.25, 0.5, 0.75],
        transform: _slide,
      );
      _shaderCallback = _shader;
    }
    if (AppMotionConfig.of(context).reduceMotion) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Shader _shader(Rect bounds) => _gradient!.createShader(bounds);

  @override
  Widget build(BuildContext context) {
    if (AppMotionConfig.of(context).reduceMotion) return widget.child;
    final callback = _shaderCallback;
    if (callback == null) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: callback,
        child: child,
      ),
    );
  }
}

/// Moves the gradient band across the child's bounds: one band width of travel
/// per sweep, entering fully off-screen left and leaving off-screen right.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.progress);

  final Animation<double> progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final travel = bounds.width * (progress.value * 2 - 1) * 2;
    return Matrix4.translationValues(travel, 0, 0);
  }
}

/// One skeleton placeholder bar in the shimmer's base colour.
///
/// Sized by the caller so the skeleton mirrors the real layout; [width] null
/// means full width, [height] defaults to a body line.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.border,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(radius)
              : null,
        ),
      ),
    );
  }
}
