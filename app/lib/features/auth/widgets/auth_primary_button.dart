/// Full-width primary CTA for the auth screens.
///
/// Pill ([AppRadius.pill], 52dp tall) filled with [AppPalette.accent] and an
/// [AppPalette.onAccent] w700 label (accent = fill, never a text colour).
///
/// Press comes from [TapScale] — the shared press primitive (0.97 spring inside
/// the 100–150 ms tap budget, released when the finger turns into a scroll).
/// The wrapper deliberately does **not** take the gesture, so the button's own
/// tap, keyboard activation and screen-reader activation are unchanged.
///
/// Haptics: this control commits, so the one haptic of the gesture is its
/// *outcome* — [Haptics.success] when the account lands, [Haptics.error] when
/// validation or the request refuses it. A press impact on top would be two
/// haptics for one tap (`core/motion/PROTOCOL.md`: one meaning per call), and
/// the platform click is off for the same reason.
///
/// While [busy] the button is not tappable and the label is replaced in place
/// by a small progress row — there is no full-screen spinner.
library;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel = 'Working…',
  });

  /// Idle label, e.g. `Log in`.
  final String label;

  /// Null disables the button; [busy] also disables it.
  final VoidCallback? onPressed;

  /// In-button progress state (replaces [label] with [busyLabel]).
  final bool busy;

  /// Label shown next to the progress indicator while [busy].
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null && !busy;
    return TapScale(
      enabled: enabled,
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            // Accent fill + onAccent label + pill shape come from the theme;
            // only the 52dp height and the fully-opaque busy fill are local.
            disabledBackgroundColor: palette.accent,
            disabledForegroundColor: palette.onAccent,
            elevation: 0,
            // The gesture's haptic is the outcome, fired by the caller.
            enableFeedback: false,
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            textStyle: AppType.body.copyWith(fontWeight: FontWeight.w700),
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.tap,
            child: busy
                ? Row(
                    key: const ValueKey('auth-busy'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.onAccent,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(busyLabel),
                    ],
                  )
                : Text(label, key: const ValueKey('auth-label')),
          ),
        ),
      ),
    );
  }
}
