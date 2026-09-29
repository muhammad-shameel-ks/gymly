/// Wordmark + one-line value prop shown above the auth form.
///
/// The `Gymly` wordmark uses [AppType.title]; the trailing `ly` carries the
/// accent wordmark colour ([AppPalette.accentText]) so the accent stays
/// legible in both themes (plain [AppPalette.accent] on light would not).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.tagline});

  /// One-line value prop under the wordmark.
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = AppType.title.copyWith(color: palette.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Gym', style: title),
              TextSpan(
                text: 'ly',
                style: title.copyWith(color: palette.accentText),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          tagline,
          style: AppType.body.copyWith(color: palette.secondary),
        ),
      ],
    );
  }
}
