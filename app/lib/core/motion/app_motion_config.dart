/// `AppMotionConfig.of(context)` — the single place Reduce Motion is read.
///
/// Every primitive in `core/motion` resolves this once per subtree instead of
/// asking `MediaQuery` again, so call sites never repeat the check and cannot
/// disagree about it:
///
/// ```dart
/// final motion = AppMotionConfig.of(context);
/// if (motion.reduceMotion) { /* opacity only, no translation */ }
/// ```
///
/// Resolution order:
/// 1. the nearest [AppMotionConfig] ancestor (install one at the app root to
///    force a scheme, or in tests to pin behaviour);
/// 2. otherwise `MediaQuery.disableAnimationsOf(context)` — the OS Reduce Motion
///    switch — wrapped in a `const` config, so the fallback allocates nothing.
///
/// What the flag means (DESIGN.md §5): keep the *state change* and the opacity
/// cross-fade, drop translation/scale/rotation, and never loop. Haptics are not
/// motion and are not gated by it.
library;

import 'package:flutter/material.dart';

import 'motion_spec.dart';

/// Resolved motion policy for a subtree.
class AppMotionConfig extends InheritedWidget {
  const AppMotionConfig({
    super.key,
    required this.reduceMotion,
    this.scheme = MotionScheme.expressive,
    required super.child,
  });

  /// True when the user asked the platform to reduce motion: opacity-only
  /// cross-fades, no translation, no loops, no spring pops.
  final bool reduceMotion;

  /// Timing scheme for this subtree. Springs are the default; [MotionScheme.standard]
  /// is the escape hatch for deterministic M3 timing.
  final MotionScheme scheme;

  /// Zero-allocation fallbacks for call sites with no [AppMotionConfig] ancestor.
  static const AppMotionConfig _reduced = AppMotionConfig(
    reduceMotion: true,
    child: SizedBox.shrink(),
  );
  static const AppMotionConfig _normal = AppMotionConfig(
    reduceMotion: false,
    child: SizedBox.shrink(),
  );

  /// Resolves the ambient motion policy, or derives it from `MediaQuery`
  /// (Reduce Motion) when no ancestor installed one.
  static AppMotionConfig of(BuildContext context) {
    final config = context.dependOnInheritedWidgetOfExactType<AppMotionConfig>();
    if (config != null) return config;
    return MediaQuery.disableAnimationsOf(context) ? _reduced : _normal;
  }

  /// Convenience for call sites that only care about the flag.
  static bool reduceMotionOf(BuildContext context) => of(context).reduceMotion;

  @override
  bool updateShouldNotify(AppMotionConfig oldWidget) =>
      oldWidget.reduceMotion != reduceMotion || oldWidget.scheme != scheme;
}

/// `context.motion` — sugar for [AppMotionConfig.of].
extension AppMotionContext on BuildContext {
  /// Resolved motion policy for this subtree (Reduce Motion + scheme).
  AppMotionConfig get motion => AppMotionConfig.of(this);
}
