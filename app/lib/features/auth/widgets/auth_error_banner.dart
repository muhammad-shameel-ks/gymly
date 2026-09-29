/// Inline auth error banner + the voice mapping for failed auth.
///
/// [AppPalette.error] tinted fill + border with error text (icon + message).
/// The entrance is the motion layer's [RiseIn] ([MotionSpec.appear], 250 ms):
/// a short rise + fade, or an opacity-only cross-fade under Reduce Motion, and
/// the play latches per mount so a rebuild never replays it. Announced as a
/// live region so screen readers surface the message; the caller pairs it with
/// [Haptics.error] — the banner owns no timing of its own.
library;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

/// The owner-readable line for a failed sign-in/sign-up.
///
/// Supabase's auth messages are written for developers ("Invalid login
/// credentials"), so the ones an owner can act on are mapped to the voice spec
/// (second person; what happened → what to do); anything unknown is surfaced
/// verbatim, so a failure is never silently swallowed.
String authErrorMessage(String serverMessage) {
  final message = serverMessage.toLowerCase();
  if (message.contains('invalid login credentials')) {
    return "That email and password don't match. Check them, then try again.";
  }
  if (message.contains('email not confirmed')) {
    return 'Confirm your email first, then log in.';
  }
  if (message.contains('already registered')) {
    return 'This email already has an account. Log in instead.';
  }
  if (message.contains('at least 6 characters')) {
    return 'Enter at least 6 characters.';
  }
  if (message.contains('rate limit') || message.contains('too many')) {
    return 'Too many attempts. Wait a minute, then try again.';
  }
  return serverMessage;
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  /// Owner-facing error text, already in the voice spec (see
  /// [authErrorMessage] for the auth failures).
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return RiseIn(
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: palette.error.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: palette.error.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: palette.error),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppType.body.copyWith(color: palette.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
