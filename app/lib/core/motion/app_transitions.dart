/// `AppTransitions` — how a screen arrives and leaves.
///
/// **Communicates:** *where you came from.* A push slides the new screen in
/// horizontally from the trailing edge (LTR) while the outgoing screen drifts a
/// little the other way; a pop plays the same motion backwards. The direction is
/// the navigation model, not decoration — so it is never swapped for a fade on
/// gesture-linked motion.
///
/// **Budget:** [MotionSpec.push] — 325 ms in, 300 ms out (the DESIGN.md §5
/// 300–350 ms band). Transform + opacity only.
///
/// **Platform-appropriate:** iOS/macOS keep the native Cupertino transition
/// (parallax + edge-swipe back, so the platform's own gesture is untouched);
/// Android keeps the framework's predictive-back builder so the system back
/// gesture is never hijacked; desktop gets [AppSlideFadeTransitionsBuilder]
/// explicitly. All three have their duration pulled into the app's budget.
///
/// **Reduce Motion:** every builder returns an opacity-only cross-fade — no
/// translation, no parallax. On the gesture-driven platforms that is a
/// deliberate trade: reduce-motion users get the cross-fade instead of the
/// finger-following transition, and the back button/gesture still pops.
///
/// Wire-up is one line in [AppTheme]; screens never touch this.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_motion_config.dart';
import 'motion_spec.dart';

/// Cross-platform directional push/pop: slide 25% + fade in, secondary drift.
///
/// Used for desktop by [AppTransitions.theme] and available to any route that
/// wants the app transition directly.
class AppSlideFadeTransitionsBuilder extends PageTransitionsBuilder {
  const AppSlideFadeTransitionsBuilder();

  @override
  Duration get transitionDuration => MotionSpec.push.duration;

  @override
  Duration get reverseTransitionDuration => MotionSpec.push.reverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotionConfig.of(context).reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final enter = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );
    final slide = Tween<Offset>(
      begin: Offset(rtl ? -0.25 : 0.25, 0),
      end: Offset.zero,
    ).animate(enter);
    // The outgoing screen only drifts, so the incoming slide stays the signal.
    final drift = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(rtl ? 0.08 : -0.08, 0),
    ).animate(exit);
    return SlideTransition(
      position: drift,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(opacity: enter, child: child),
      ),
    );
  }
}

/// iOS/macOS: the native Cupertino transition, on the app's push budget.
class AppCupertinoTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const AppCupertinoTransitionsBuilder();

  @override
  Duration get transitionDuration => MotionSpec.push.duration;

  @override
  Duration get reverseTransitionDuration => MotionSpec.push.reverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotionConfig.of(context).reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    return super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Android: the framework's predictive-back transition, on the app's budget.
class AppPredictiveBackTransitionsBuilder
    extends PredictiveBackPageTransitionsBuilder {
  const AppPredictiveBackTransitionsBuilder();

  @override
  Duration get transitionDuration => MotionSpec.push.duration;

  @override
  Duration get reverseTransitionDuration => MotionSpec.push.reverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotionConfig.of(context).reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    return super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// The app's `pageTransitionsTheme`, applied in both themes by [AppTheme].
abstract final class AppTransitions {
  /// Platform map wired into `ThemeData.pageTransitionsTheme`.
  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: AppPredictiveBackTransitionsBuilder(),
      TargetPlatform.iOS: AppCupertinoTransitionsBuilder(),
      TargetPlatform.macOS: AppCupertinoTransitionsBuilder(),
      TargetPlatform.linux: AppSlideFadeTransitionsBuilder(),
      TargetPlatform.windows: AppSlideFadeTransitionsBuilder(),
    },
  );

  /// Transition used for an app-owned [PageRoute] (and for desktop).
  static const PageTransitionsBuilder builder =
      AppSlideFadeTransitionsBuilder();

  /// Controller for a modal sheet that must match the app's sheet budget.
  ///
  /// Pass to `showModalBottomSheet(transitionAnimationController: …)`; the
  /// caller owns it and must dispose it. Under Reduce Motion the duration
  /// collapses to the cross-fade budget so the sheet arrives without travel.
  static AnimationController sheetController(
    TickerProvider vsync, {
    bool reduceMotion = false,
  }) {
    return AnimationController(
      vsync: vsync,
      duration: reduceMotion ? AppMotion.crossFade : MotionSpec.sheet.duration,
      reverseDuration: reduceMotion
          ? AppMotion.crossFade
          : MotionSpec.sheet.reverse,
      animationBehavior: AnimationBehavior.preserve,
    );
  }
}
