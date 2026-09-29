/// Light/dark [ThemeData] built from [AppPalette] + [AppType].
///
/// Both themes register [AppPalette] as a `ThemeExtension`, so
/// `context.palette` / `Theme.of(context).extension<AppPalette>()` resolve in
/// either mode. Component defaults live here so screens keep their per-screen
/// layout and only set what is genuinely local.
library;

import 'package:flutter/material.dart';

import '../motion/app_transitions.dart';
import 'app_palette.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);
  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      // Material defaults paint text/icons with `primary`; that must be the
      // legible accent, not the fill accent.
      primary: p.accentText,
      onPrimary: p.onAccent,
      primaryContainer: p.accent,
      onPrimaryContainer: p.onAccent,
      secondary: p.accentText,
      onSecondary: p.onAccent,
      error: p.error,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.secondary,
      surfaceTint: Colors.transparent,
      outline: p.border,
      outlineVariant: p.border,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      borderSide: BorderSide(color: p.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppType.family,
      colorScheme: scheme,
      // Screen-to-screen motion lives in one place: core/motion/app_transitions.
      pageTransitionsTheme: AppTransitions.theme,
      extensions: <ThemeExtension<dynamic>>[p],
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.border,
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarThemeData(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.subtitle.copyWith(color: p.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.55),
        // The one grabber pill above every sheet (`showAppSheet`): one neutral
        // hairline-width capsule, ~32×5, centred — `border`, never a hex
        // (DESIGN.md §4, “Sheets”). The framework's 48 dp strip around it stays
        // the drag target.
        dragHandleColor: p.border,
        dragHandleSize: const Size(32, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppType.subtitle.copyWith(color: p.text),
        contentTextStyle: AppType.body.copyWith(color: p.secondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          side: BorderSide(color: p.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface,
        contentTextStyle: AppType.body.copyWith(color: p.text),
        actionTextColor: p.accentText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: p.border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accentText,
        linearTrackColor: p.border,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.accent.withValues(alpha: 0.35),
          disabledForegroundColor: p.onAccent.withValues(alpha: 0.65),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          minimumSize: const Size(48, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accentText,
          side: BorderSide(color: p.border),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.secondary,
          selectedBackgroundColor: p.accent,
          selectedForegroundColor: p.onAccent,
          side: BorderSide(color: p.border),
          textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.md,
        ),
        labelStyle: AppType.body.copyWith(color: p.secondary),
        floatingLabelStyle: AppType.caption.copyWith(color: p.accentText),
        hintStyle: AppType.body.copyWith(
          color: p.secondary.withValues(alpha: 0.7),
        ),
        errorStyle: AppType.caption.copyWith(color: p.error),
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.accentText, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.secondary,
        textColor: p.text,
      ),
    );
  }
}
