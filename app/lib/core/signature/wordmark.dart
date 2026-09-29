/// The `Gymly` wordmark — one widget, so the brand is identical everywhere it
/// introduces itself.
///
/// `Gym` takes [AppType.title] in [AppPalette.text]; the trailing `ly` carries
/// [AppPalette.accentText] — the accent *as* text, because plain
/// [AppPalette.accent] on a light surface cannot meet 4.5:1.
///
/// The auth hero (`AuthHero`) and the launch surface (`LaunchSplash`) both render
/// *this* widget, so the handoff from launch to login does not move, resize or
/// recolour the mark.
///
/// Not decoration: the mark appears where the app introduces itself (launch,
/// auth), never as a per-screen header. The app's one held motif is still
/// `DueRing`.
library;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// Two-tone `Gymly` wordmark: `Gym` in [AppPalette.text], `ly` in
/// [AppPalette.accentText].
class GymlyWordmark extends StatelessWidget {
  const GymlyWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final head = AppType.title.copyWith(color: palette.text);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Gym', style: head),
          TextSpan(
            text: 'ly',
            style: head.copyWith(color: palette.accentText),
          ),
        ],
      ),
    );
  }
}
