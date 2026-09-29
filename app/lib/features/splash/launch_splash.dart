/// The branded launch surface: a full-bleed [AppPalette.surface] screen with the
/// [GymlyWordmark] centred, cross-fading into the live app.
///
/// It is a *surface*, not a screen: no scaffolding, no safe area, no chrome, no
/// spinner. `SplashGate` paints it above the app, whose first frame is already
/// underneath, so this widget never holds a frame back and never leaves the user
/// looking at nothing.
///
/// The colour is the same one the OS window is painted with before Flutter
/// starts (`android:colorBackground` in `values/` and `values-night/`
/// `styles.xml`; the iOS system background in `LaunchScreen.storyboard`), so the
/// native launch and this surface read as one continuous brand screen.
library;

import 'package:flutter/material.dart';

import '../../core/signature/wordmark.dart';
import '../../core/theme/app_palette.dart';

class LaunchSplash extends StatelessWidget {
  const LaunchSplash({
    super.key,
    required this.progress,
    required this.reduceMotion,
  });

  /// Handoff progress: 0 while the launch surface owns the screen, 1 once the
  /// app has taken over. Opacity is always `1 - progress`.
  final Animation<double> progress;

  /// Reduce Motion: the mark cross-fades in place — the settle scale is dropped,
  /// nothing travels.
  final bool reduceMotion;

  /// How far the mark settles back (fraction of its size) as the app arrives.
  static const double _settle = 0.06;

  @override
  Widget build(BuildContext context) {
    final surface = context.palette.surface;
    return AnimatedBuilder(
      animation: progress,
      child: const GymlyWordmark(),
      builder: (BuildContext context, Widget? mark) {
        final t = progress.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - t,
          child: ColoredBox(
            color: surface,
            child: Center(
              child: reduceMotion
                  ? mark
                  : Transform.scale(scale: 1 - _settle * t, child: mark),
            ),
          ),
        );
      },
    );
  }
}
