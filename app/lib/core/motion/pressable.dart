/// `PressableCard` / `PressableRow` — pressable surfaces.
///
/// **Communicates:** the same thing as [TapScale] — "this surface is a control"
/// — but for a full card/row: the whole surface scales a hair (0.985) and takes
/// a translucent overlay, so the *surface* reads as pressed instead of the text
/// going dim. Callers hand in the same [onTap] they would give an [InkWell].
///
/// **Budget:** [MotionSpec.tap] — spring press-down, spring release, inside the
/// 100–150 ms budget. Transform + opacity only, so list scrolling is unaffected.
///
/// **Reduce Motion:** the scale is dropped and only the overlay cross-fades
/// ([AppMotion.tap] duration), which keeps the press legible without movement.
///
/// **Haptics:** one [HapticStrength.light] impact per confirmed tap by default
/// (`Haptics.impact`), overridable per surface; `enableHaptic: false` when the
/// enclosing flow already fires one (e.g. a card whose action opens a sheet that
/// haptics on arrival — use [HapticStrength.light] on only one of them).
///
/// The press state is released when the pointer leaves `kTouchSlop`, so a drag
/// that starts on a card never leaves it stuck in the pressed look.
///
/// **Nesting:** an inner button wins its own tap (Flutter's arena), but the card
/// would still flash its press state on the way down. So a card whose content
/// carries its own actions (the dues card's Pay/Call/WhatsApp) should be
/// inert — pass no `onTap` — and let the buttons own their presses; use
/// [PressableRow] for a row that is itself the one action.
library;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import 'haptics.dart';
import 'tap_scale.dart';

/// Card-shaped pressable surface: `surface` fill, card radius, hairline border.
class PressableCard extends StatelessWidget {
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = HapticStrength.light,
    this.enableHaptic = true,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.margin,
    this.color,
    this.borderRadius,
    this.showBorder = true,
    this.pressScale = 0.985,
    this.overlayOpacity = 0.06,
    this.semanticsLabel,
  });

  final Widget child;

  /// Tap handler; null makes the card static (decoration only, no press state).
  final VoidCallback? onTap;

  /// Optional long press (e.g. quick actions).
  final VoidCallback? onLongPress;

  final HapticStrength haptic;
  final bool enableHaptic;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Surface fill; defaults to `context.palette.surface`.
  final Color? color;

  /// Defaults to [AppRadius.card].
  final BorderRadius? borderRadius;

  /// Hairline [AppPalette.border]; off for borderless cards.
  final bool showBorder;

  final double pressScale;

  /// Overlay alpha of `white`/`black` (per mode) while pressed.
  final double overlayOpacity;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.card);
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: radius,
        border: showBorder ? Border.all(color: palette.border) : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    final decorated = margin == null
        ? surface
        : Padding(padding: margin!, child: surface);
    if (onTap == null && onLongPress == null) return decorated;
    return TapScale(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: haptic,
      enableHaptic: enableHaptic,
      scale: pressScale,
      pressOverlay: _overlay(palette, overlayOpacity),
      pressOverlayRadius: radius,
      semanticsLabel: semanticsLabel,
      child: decorated,
    );
  }
}

/// Row-shaped pressable surface: same press contract, list-row metrics
/// ([AppSpace.md] padding, card radius, no border) for `ListView` children.
class PressableRow extends StatelessWidget {
  const PressableRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = HapticStrength.light,
    this.enableHaptic = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.md,
    ),
    this.margin,
    this.color,
    this.borderRadius,
    this.pressScale = 0.99,
    this.overlayOpacity = 0.06,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HapticStrength haptic;
  final bool enableHaptic;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius? borderRadius;
  final double pressScale;
  final double overlayOpacity;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.card);
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: radius,
      ),
      child: Padding(padding: padding, child: child),
    );
    final decorated = margin == null
        ? surface
        : Padding(padding: margin!, child: surface);
    if (onTap == null && onLongPress == null) return decorated;
    return TapScale(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: haptic,
      enableHaptic: enableHaptic,
      scale: pressScale,
      pressOverlay: _overlay(palette, overlayOpacity),
      pressOverlayRadius: radius,
      semanticsLabel: semanticsLabel,
      child: decorated,
    );
  }
}

Color _overlay(AppPalette palette, double opacity) {
  final base = palette.isDark ? Colors.white : Colors.black;
  return base.withValues(alpha: opacity);
}
