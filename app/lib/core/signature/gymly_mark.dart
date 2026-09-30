/// The `Gymly` brand mark: the [DueRing] motif with a dumbbell at its centre —
/// the ring that fills as money comes in, around the thing the gym sells.
///
/// Painted from **palette tokens**, exactly like [DueRing], so it is correct in
/// both themes: the track is `palette.border`, the paid share is
/// `palette.accent`, and the dumbbell is `palette.text` (near-white in dark,
/// near-black in light). A raster mark would bake the dark-theme greys and
/// vanish on the light theme, which is why this is a painter — the same reason
/// the launcher icon's vector sources (`assets/branding/`) are rasterized only
/// for the OS, never for the app.
///
/// Geometry is the icon source's, at 1024ths of the canvas, so the mark on the
/// launch surface is the same drawing as the launcher icon.
///
/// Not decoration: it introduces the app (launch surface, auth hero) and never
/// heads a working screen. The app's one held motif on screens stays [DueRing].
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The brand mark at [size] logical pixels square, themed from [context].
class GymlyMark extends StatelessWidget {
  const GymlyMark({super.key, this.size = 64});

  /// Width and height of the (square) mark.
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      // The wordmark beside it already says "Gymly": one announcement, not two.
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(
          track: palette.border,
          share: palette.accent,
          grip: palette.text,
        ),
      ),
    );
  }
}

/// Draws the mark: ring track, the paid share from 12 o'clock, then a dumbbell.
///
/// Every dimension is a fraction of the shortest side, taken from
/// `assets/branding/icon.svg` (ring radius 300/1024, stroke 58/1024, dumbbell
/// plates 98×168 at ±183, bar 244×44) so the painted mark and the launcher icon
/// cannot drift apart.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.track,
    required this.share,
    required this.grip,
  });

  final Color track;
  final Color share;
  final Color grip;

  /// Share of the ring filled in the icon: 100°, clockwise from 12 o'clock.
  static const double _sweep = 100 * math.pi / 180;

  static const double _ringRadius = 300 / 1024;
  static const double _stroke = 58 / 1024;
  static const double _plateWidth = 98 / 1024;
  static const double _plateHeight = 168 / 1024;
  static const double _plateOffset = 183 / 1024;
  static const double _barWidth = 244 / 1024;
  static const double _barHeight = 44 / 1024;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = size.center(Offset.zero);
    final radius = side * _ringRadius;
    final stroke = side * _stroke;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, radius, ring..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      _sweep,
      false,
      ring..color = share,
    );

    final gripPaint = Paint()..color = grip;
    void rounded(double dx, double width, double height, double corner) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centre + Offset(dx * side, 0),
            width: width * side,
            height: height * side,
          ),
          Radius.circular(corner * side),
        ),
        gripPaint,
      );
    }

    rounded(-_plateOffset, _plateWidth, _plateHeight, 30 / 1024);
    rounded(_plateOffset, _plateWidth, _plateHeight, 30 / 1024);
    rounded(0, _barWidth, _barHeight, 22 / 1024);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.track != track || old.share != share || old.grip != grip;
}
