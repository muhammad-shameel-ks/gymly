/// Themed palette — the single source of colour truth (DESIGN.md §4).
///
/// Registered as a [ThemeExtension] in both light and dark `ThemeData`, so
/// `context.palette` always resolves. Rules:
///
/// - **`accent` is a FILL colour** — button/chip/FAB backgrounds and nothing
///   else. Pair it with [onAccent] for the label.
/// - **`accentText` is the accent used AS text/icon/border colour** (active
///   tab, links, focused field borders, focused outlines). It is deliberately
///   darker in light mode, where the fill accent cannot meet 4.5:1 as text.
/// - **Status colours** are semantic only: [error] destructive/validation,
///   [success] confirmation, [warning] caution. Never decoration.
/// - Neutrals carry ~90% of the surface; hierarchy comes from size, weight and
///   position before colour.
library;

import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.secondary,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.error,
    required this.success,
    required this.warning,
    required this.isDark,
  });

  /// Screen background.
  final Color bg;

  /// Card / sheet / elevated surface.
  final Color surface;

  /// Hairline borders and dividers.
  final Color border;

  /// Primary text.
  final Color text;

  /// Secondary text, hints, inactive icons.
  final Color secondary;

  /// Brand fill: primary actions + selected state ONLY.
  final Color accent;

  /// Text/icon drawn ON TOP of [accent].
  final Color onAccent;

  /// [accent] used as a text/icon/border colour.
  final Color accentText;

  final Color error;
  final Color success;
  final Color warning;

  final bool isDark;

  /// Dark-first default. Indigo brand on cool graphite neutrals.
  static const AppPalette dark = AppPalette(
    bg: Color(0xFF0B0C10),
    surface: Color(0xFF14161C),
    border: Color(0xFF262A33),
    text: Color(0xFFF2F3F7),
    secondary: Color(0xFF9AA1B1),
    accent: Color(0xFF6366F1),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFFA5B4FC),
    error: Color(0xFFFF6B6B),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    isDark: true,
  );

  /// Light mirror: same brand family, deepened for contrast on white.
  static const AppPalette light = AppPalette(
    bg: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE3E6EF),
    text: Color(0xFF101322),
    secondary: Color(0xFF5C6478),
    accent: Color(0xFF4F46E5),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF4338CA),
    error: Color(0xFFC62828),
    success: Color(0xFF15803D),
    warning: Color(0xFF8A5300),
    isDark: false,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? border,
    Color? text,
    Color? secondary,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? error,
    Color? success,
    Color? warning,
    bool? isDark,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      text: text ?? this.text,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// `context.palette` accessor.
extension AppPaletteX on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
