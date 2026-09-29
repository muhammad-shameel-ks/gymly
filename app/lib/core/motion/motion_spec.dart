/// `MotionSpec` — the budget table the whole app animates on.
///
/// One entry per *interaction*, each carrying both schemes from
/// `AppMotion` (DESIGN.md §5):
///
/// - [spring] — expressive: a [SpringDescription]. Gesture-linked motion always
///   uses this, so the finger's velocity is part of the result.
/// - [curve] + [duration] — standard: the M3 cubic-bezier fallback, used when a
///   spring cannot drive the value (route transitions, count-ups, reduce-motion
///   cross-fades) or when the expressive scheme is switched off.
///
/// Budgets (never exceeded): tap 100–150 ms · toggle 150–200 ms · appear
/// 200–300 ms (stagger 40 ms) · push/pop 300–350 ms · sheet 350–500 ms.
///
/// Reduce Motion: a spec is still the source of the *shape* of the animation,
/// but [AppMotionConfig] decides whether motion is allowed at all. Under Reduce
/// Motion the primitives keep opacity and drop translation — see
/// `AppMotionConfig.reduceMotion` and the cross-fade budget
/// `AppMotion.crossFade`.
///
/// Drive a controller through [drive] so every call site makes the
/// spring-or-curve decision the same way.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_tokens.dart';

/// Which timing scheme a call site paints with.
enum MotionScheme {
  /// Springs (default). Physical, velocity-aware, never decorative.
  expressive,

  /// M3 cubic-bezier + token duration. Deterministic; used for transitions and
  /// when a spring has nothing physical to model.
  standard,
}

/// One interaction's timing: spring (expressive) + curve/duration (standard).
@immutable
final class MotionSpec {
  const MotionSpec({
    required this.spring,
    required this.curve,
    required this.duration,
    Duration? reverse,
  }) : reverse = reverse ?? duration;

  /// Expressive scheme: the spring to drive with.
  final SpringDescription spring;

  /// Standard scheme: the M3 cubic-bezier fallback.
  final Curve curve;

  /// Standard scheme: the budget for this interaction.
  final Duration duration;

  /// Reverse budget (pop/dismiss is always ≤ forward).
  final Duration reverse;

  /// Press-down / release (120 ms, ζ 1.0 / 0.7).
  static const MotionSpec tap = MotionSpec(
    spring: AppMotion.springTap,
    curve: AppMotion.standardDecelerate,
    duration: AppMotion.tap,
  );

  /// Press *release*: same budget, underdamped, so the snap back has a give.
  static const MotionSpec tapRelease = MotionSpec(
    spring: AppMotion.springTapRelease,
    curve: AppMotion.standardDecelerate,
    duration: AppMotion.tap,
  );

  /// Toggle / chip / switch travel (175 ms).
  static const MotionSpec toggle = MotionSpec(
    spring: AppMotion.springToggle,
    curve: AppMotion.standard,
    duration: AppMotion.toggle,
  );

  /// Card / row / section entrance (250 ms, ~40 ms stagger between them).
  static const MotionSpec appear = MotionSpec(
    spring: AppMotion.springAppear,
    curve: AppMotion.emphasizedDecelerate,
    duration: AppMotion.appear,
  );

  /// Route push (325 ms) / pop (300 ms) — directional.
  static const MotionSpec push = MotionSpec(
    spring: AppMotion.springAppear,
    curve: AppMotion.standardDecelerate,
    duration: AppMotion.push,
    reverse: Duration(milliseconds: 300),
  );

  /// Modal sheet up (425 ms) / down (240 ms).
  static const MotionSpec sheet = MotionSpec(
    spring: AppMotion.springSheet,
    curve: AppMotion.emphasizedDecelerate,
    duration: AppMotion.sheet,
    reverse: AppMotion.sheetClose,
  );

  /// Selection / status-bucket change: one deliberate pop (200 ms, ζ 0.45).
  static const MotionSpec pop = MotionSpec(
    spring: AppMotion.springPop,
    curve: AppMotion.overshoot,
    duration: AppMotion.selection,
    reverse: AppMotion.tap,
  );

  /// Bounded fill / reset in place: due ring, progress arc, meter (300 ms in,
  /// 175 ms back out). Drive a controller bounded `0..1` so the ζ 0.9 settle is
  /// clamped and the fill can never pass the value it is reporting.
  static const MotionSpec fill = MotionSpec(
    spring: AppMotion.springFill,
    curve: AppMotion.emphasizedDecelerate,
    duration: AppMotion.fill,
    reverse: AppMotion.toggle,
  );

  /// Integer / currency count-up (280 ms, critically damped).
  static const MotionSpec count = MotionSpec(
    spring: AppMotion.springCount,
    curve: AppMotion.emphasizedDecelerate,
    duration: AppMotion.count,
  );

  /// Reduce Motion fallback: opacity only, no translation (160 ms).
  static const MotionSpec crossFade = MotionSpec(
    spring: AppMotion.springCount,
    curve: Curves.easeOut,
    duration: AppMotion.crossFade,
    reverse: AppMotion.crossFade,
  );

  /// Spring simulation for this spec, from `current` to `target`,
  /// carrying `velocity` so an interrupted gesture continues naturally.
  SpringSimulation simulation(
    double current,
    double target, {
    double velocity = 0.0,
  }) => SpringSimulation(spring, current, target, velocity);
}

/// Drives a controller with the scheme the caller resolved.
extension MotionSpecDrive on MotionSpec {
  /// Animates [controller] towards [target] with a spring
  /// ([MotionScheme.expressive]) or with [curve]/[duration]
  /// ([MotionScheme.standard]).
  ///
  /// Callbacks are the call site's job: keep controllers bounded so a spring
  /// overshoot cannot escape the visual it is animating.
  TickerFuture drive(
    AnimationController controller, {
    required double target,
    MotionScheme scheme = MotionScheme.expressive,
    double velocity = 0.0,
    Duration? duration,
  }) {
    if (scheme == MotionScheme.standard) {
      return controller.animateTo(
        target,
        duration: duration ?? this.duration,
        curve: curve,
      );
    }
    return controller.animateWith(
      simulation(controller.value, target, velocity: velocity),
    );
  }
}
