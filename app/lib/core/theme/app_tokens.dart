/// Design tokens — single source of truth (DESIGN.md §4).
///
/// Spacing on a 4-base; one radius per role; three type levels; dark-first
/// palette with one volt accent (primary actions + active tab ONLY).
///
/// [AppMotion] also carries the motion budget table and both spring/cubic-bezier
/// schemes described in DESIGN.md §5; `lib/core/motion/` builds the primitives
/// on top of it.
library;

import 'package:flutter/material.dart';

/// Spacing (4-base). Screen padding 20–24 → [screen].
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal screen padding.
  static const double screen = 20;

  /// Standard gap between list rows/cards.
  static const double gap = 8;
}

/// Corner radii — one per role.
abstract final class AppRadius {
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;
}

/// Type — three levels, one family (Inter; platform fallback automatic).
///
/// Metrics only: deliberately carries NO colour so a themed surface cannot
/// inherit a dark-only text colour. Callers set the colour explicitly:
/// `AppType.body.copyWith(color: context.palette.text)`.
abstract final class AppType {
  /// Bundled family (assets/fonts, weights 400/500/600/700).
  static const String family = 'PlusJakartaSans';

  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 32 / 26,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: family,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 26 / 19,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
  );
}

/// Motion tokens (DESIGN.md §5). Transform/opacity only, never layout.
///
/// Two schemes, one budget table:
///
/// - **expressive** — the `spring*` [SpringDescription]s below. Used for
///   anything gesture-linked (press, pop, sheet) because a spring keeps the
///   finger's velocity part of the motion.
/// - **standard** — M3 cubic-bezier fallbacks ([standard], [standardDecelerate],
///   [standardAccelerate], [emphasizedDecelerate], [emphasizedAccelerate],
///   [overshoot]) paired with the durations above. Used where a spring cannot
///   drive the value: route transitions, count-ups, reduce-motion cross-fades.
///
/// Spring damping ratios are noted per field;
/// `damping = ratio * 2 * sqrt(mass * stiffness)`. All springs are critically
/// damped unless the comment says otherwise — overshoot is opt-in, never ambient.
///
/// `core/motion` composes these into [MotionSpec]s; screens should use the
/// primitives there rather than raw controller timing.
abstract final class AppMotion {
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration toggle = Duration(milliseconds: 175);
  static const Duration appear = Duration(milliseconds: 250);
  static const Duration push = Duration(milliseconds: 325);
  static const Duration sheet = Duration(milliseconds: 425);

  /// Stagger between appearing cards/rows.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Chip / check / status-bucket change (spring pop territory).
  static const Duration selection = Duration(milliseconds: 200);

  /// Bounded 0→1 fill / reset in place (due ring, progress arc, meter).
  static const Duration fill = Duration(milliseconds: 300);

  /// Reduce Motion fallback: opacity only, translation dropped.
  static const Duration crossFade = Duration(milliseconds: 160);

  /// Integer / currency count-up.
  static const Duration count = Duration(milliseconds: 280);

  /// Modal sheet dismissal (leaving is faster than arriving).
  static const Duration sheetClose = Duration(milliseconds: 240);

  // ---------------------------------------------------------------------------
  // Standard scheme — M3 cubic-bezier fallbacks.
  // ---------------------------------------------------------------------------

  /// M3 standard easing, cubic-bezier(0.2, 0, 0, 1). (M3's deprecated
  /// `emphasized` is the same curve; use the two named decelerate/accelerate
  /// forms below where direction matters.)
  static const Cubic standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// M3 standard decelerate, cubic-bezier(0, 0, 0, 1) — things arriving.
  static const Cubic standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);

  /// M3 standard accelerate, cubic-bezier(0.3, 0, 1, 1) — things leaving.
  static const Cubic standardAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  /// M3 emphasized decelerate, cubic-bezier(0.05, 0.7, 0.1, 1).
  static const Cubic emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// M3 emphasized accelerate, cubic-bezier(0.3, 0, 0.8, 0.15).
  static const Cubic emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Small overshoot (~3%) for pops when a spring is not available.
  static const Cubic overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

  // ---------------------------------------------------------------------------
  // Expressive scheme — springs (mass 1).
  // ---------------------------------------------------------------------------

  /// Press-down: critically damped (ζ 1.0), settles in ~150 ms.
  static const SpringDescription springTap = SpringDescription(
    mass: 1,
    stiffness: 700,
    damping: 52.92,
  );

  /// Press-release: underdamped (ζ 0.7) so the snap back has a ~1% give.
  static const SpringDescription springTapRelease = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 31.30,
  );

  /// Toggle / chip travel: critically damped, settles in ~180 ms.
  static const SpringDescription springToggle = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 44.72,
  );

  /// Card / row entrance: ζ 0.85, settles in ~250 ms. The only spring with
  /// visible (sub-pixel) settle, and only at the very end.
  static const SpringDescription springAppear = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 30.41,
  );

  /// Sheet up: ζ 0.85, settles in ~400 ms — soft, deliberate, no bounce.
  static const SpringDescription springSheet = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 27.41,
  );

  /// Status-dot / check pop: ζ 0.45, one clear overshoot then done.
  static const SpringDescription springPop = SpringDescription(
    mass: 1,
    stiffness: 600,
    damping: 22.05,
  );

  /// Bounded fill / reset (due ring, progress arc): ζ 0.9 — the tiny settle is
  /// under a pixel of travel, so a fill never reads as overshooting the value.
  /// Settles in ~260 ms, inside the 300 ms budget.
  static const SpringDescription springFill = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 31.18,
  );

  /// Count-up settle: critically damped, ~250 ms.
  static const SpringDescription springCount = SpringDescription(
    mass: 1,
    stiffness: 250,
    damping: 31.62,
  );
}
