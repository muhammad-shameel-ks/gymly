/// Palette-styled auth text field.
///
/// Filled [AppPalette.surface] with a [AppPalette.border] outline, 16px radius
/// ([AppRadius.card]), 16px body text and a ≥48dp tap target. Validation is
/// inline (Form validator): the error border/text use [AppPalette.error].
///
/// Focus is the theme's job and is **transform-free**: `inputDecorationTheme`
/// carries the focused border (`accentText`) and the floating label, and
/// `InputDecorator` animates both in place. Nothing here moves, resizes or
/// re-pads the field on focus — the copy above the field never shifts, and the
/// press response of a field is its own focused border/caret rather than a
/// scale (a scaling input would read as a button).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.focusNode,
    this.enabled = true,
  });

  final TextEditingController controller;

  /// Floating label above the value.
  final String label;

  /// Placeholder shown while empty.
  final String? hintText;

  /// Inline validation (see [Form]).
  final FormFieldValidator<String>? validator;

  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: palette.text,
      style: AppType.body.copyWith(color: palette.text),
      // Surface fill, radius, borders, focused `accentText` and the error
      // colour all come from the theme's `inputDecorationTheme`.
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 14,
        ),
      ),
    );
  }
}
