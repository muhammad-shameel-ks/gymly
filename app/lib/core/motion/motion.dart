/// `core/motion` — the shared motion layer: import this file only.
///
/// One import gives a screen every motion primitive it is allowed to use:
///
/// ```dart
/// import 'package:gymly/core/motion/motion.dart';
/// ```
///
/// Contents, by job:
/// - press / tap → [TapScale], [PressableCard], [PressableRow], [Haptics]
/// - entrance → [StaggeredEntrance], [RiseIn]
/// - numbers → [AnimatedCounter], [AnimatedAmount]
/// - loading → [Shimmer], [ShimmerBox]
/// - state change → [AnimatedCheck], [AnimatedStatusDot]
/// - navigation → [AppTransitions], [TabTransition], [MotionSpec],
///   [AppMotionConfig]
///
/// Read `PROTOCOL.md` in this directory before adding motion to a screen: it has
/// the budget table, the do/don't list and the haptic meaning table.
library;

export 'animated_check.dart';
export 'animated_counter.dart';
export 'app_motion_config.dart';
export 'app_transitions.dart';
export 'haptics.dart';
export 'motion_spec.dart';
export 'pressable.dart';
export 'shimmer.dart';
export 'staggered_entrance.dart';
export 'tab_transition.dart';
export 'tap_scale.dart';
