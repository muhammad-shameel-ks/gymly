/// Amount fields for the money surfaces: ₹, whole rupees, digits only.
///
/// One field shape for every amount the owner types — the payment amount, the
/// first payment received with a new stretch, a price override. All of them
/// take whole ₹ (Indian grouping is a display concern: [rupees] formats it),
/// so the keyboard is numeric, the text never carries a symbol and parsing is
/// [rupeesOf].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `₹`-prefixed numeric field carrying whole rupees.
///
/// [validator] runs with the form's `validate()` when the sheet wraps this in a
/// `Form`; a bare sheet may validate with [rupeesOf] instead.
class RupeeField extends StatelessWidget {
  const RupeeField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.helperText,
  });

  final TextEditingController controller;

  /// Field label in the owner's words (`Amount`, `Received now`, `Price`).
  final String label;

  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹',
        helperText: helperText,
      ),
      keyboardType: TextInputType.number,
      // Whole rupees only: no decimals, no minus, no stray characters.
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      validator: validator,
    );
  }
}

/// `"1200"` → `1200`; blank, junk or a value out of `int` range → `null`.
int? rupeesOf(String raw) => int.tryParse(raw.trim());
