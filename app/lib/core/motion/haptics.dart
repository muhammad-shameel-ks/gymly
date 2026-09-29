/// `Haptics` — the one place haptics are fired, so a buzz always means the same
/// thing (DESIGN.md §5).
///
/// Rules:
/// - **Always pair with a visible change.** A haptic is confirmation of
///   something the eye can also verify; never fire it on scroll ticks, on
///   background data changes, or as decoration.
/// - **One meaning per call** — see the table in `PROTOCOL.md`:
///   [select] = moving through discrete values (picker, segmented control, chip);
///   [impact] = a control was pressed / snapped (light), a surface arrived
///   (medium), a destructive or heavy commitment (heavy);
///   [success] = save / renew / convert committed;
///   [error] = validation failed, destructive action refused;
///   [sheet] = a modal surface came up or went away.
/// - **Device settings win.** All of these route through Flutter's
///   `HapticFeedback`, which the OS honours according to the system haptics
///   setting (iOS *System Haptics*, Android *Touch feedback*). Nothing here
///   bypasses that, and [enabled] is only an app-level kill switch (e.g. a
///   future in-app toggle) — it defaults to on.
///
/// iOS `prepare()` guidance: `UIImpactFeedbackGenerator.prepare()` warm-up is
/// **not exposed by Flutter**; the engine creates and prepares the generators
/// itself, so the first tap of a session does not need an app-side call. Call
/// [prepare] from the interaction's press-down if the app ever gains a native
/// haptics channel — today it is a deliberate no-op kept so that upgrade does
/// not touch call sites. On Android the equivalent (`performHapticFeedback`
/// pre-warm) does not exist; the platform handles the actuator latency.
library;

import 'package:flutter/services.dart';

/// Haptic weight for [Haptics.impact].
enum HapticStrength {
  /// Snap / toggle. Matches a press-scale or a switch flipping.
  light,

  /// Surface arrival (sheet, card expanding) or a secondary commitment.
  medium,

  /// Destructive or irreversible commitment.
  heavy,
}

/// Semantic haptics. Fire from the gesture handler, immediately next to the
/// visual change it confirms.
abstract final class Haptics {
  /// App-level kill switch. Device settings are honoured by the platform
  /// regardless of this flag; it exists for an in-app preference only.
  static bool enabled = true;

  /// Discrete value changed: picker scroll, segmented control, chip select.
  static void select() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  /// A control was pressed or a surface moved. [strength] defaults to
  /// [HapticStrength.light] (snap/toggle).
  static void impact({HapticStrength strength = HapticStrength.light}) {
    if (!enabled) return;
    if (strength == HapticStrength.heavy) {
      HapticFeedback.heavyImpact();
    } else if (strength == HapticStrength.medium) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Committed: member saved, membership renewed, inquiry converted.
  static void success() {
    if (!enabled) return;
    HapticFeedback.successNotification();
  }

  /// Refused: validation failure or a destructive action that did not go
  /// through. Pairs with the error colour/text, never with a success toast.
  static void error() {
    if (!enabled) return;
    HapticFeedback.errorNotification();
  }

  /// Modal surface arrived or left (bottom sheet, dialog, gym switcher).
  static void sheet() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// iOS Taptic Engine warm-up. See the library doc: Flutter exposes no
  /// `prepare()`, so this is a no-op today and a seam for a future native
  /// haptics channel. Cheap to call on press-down.
  static void prepare() {
    // Intentionally empty — see the iOS `prepare()` guidance above.
  }
}
