/// Wordmark + one-line value prop shown above the auth form.
///
/// The mark itself is [GymlyWordmark] (`core/signature/wordmark.dart`) — the
/// same widget the launch surface paints, on [AppType.title] with the trailing
/// `ly` in [AppPalette.accentText] so the accent stays legible in both themes.
library;

import 'package:flutter/material.dart';

import '../../../core/signature/wordmark.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.tagline});

  /// One-line value prop under the wordmark.
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GymlyWordmark(),
        const SizedBox(height: AppSpace.sm),
        Text(
          tagline,
          style: AppType.body.copyWith(color: palette.secondary),
        ),
      ],
    );
  }
}
