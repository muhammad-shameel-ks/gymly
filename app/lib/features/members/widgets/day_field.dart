/// Day fields: the app's one themed date picker + the read-only field that
/// opens it.
///
/// Every date the owner enters (last day he came, paid on, the day he asked to
/// switch, a corrected start date) goes through [DayField], so the picker wears
/// this app's surface, radius, type and accent instead of the framework's grey
/// M3 defaults, and one gesture keeps one haptic: [Haptics.sheet] when the
/// picker arrives, [Haptics.select] when a day is chosen.
library;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import 'money_text.dart' show shortDate;

/// A read-only date field: shows [day] as `12 Sep` and opens the themed picker.
///
/// [first]..[last] are the picker's bounds — callers pass `today` as [last] for
/// anything that must not land in the future. There is no text entry, so an
/// unparseable date is impossible; a bound the picker cannot express is the
/// caller's own guard.
class DayField extends StatelessWidget {
  const DayField({
    super.key,
    required this.label,
    required this.day,
    required this.first,
    required this.last,
    required this.onChanged,
    this.helpText,
    this.enabled = true,
  });

  /// Field label in the owner's words (`Last day he came`, `Paid on`).
  final String label;

  final DateTime day;
  final DateTime first;
  final DateTime last;

  /// The picker's title; defaults to [label].
  final String? helpText;

  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  /// Clamps into the pickable window so bad data never crashes the picker.
  DateTime get _initial {
    if (day.isBefore(first)) return first;
    if (day.isAfter(last)) return last;
    return day;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TapScale(
      enabled: enabled,
      // The picker fires Haptics.sheet() itself when it comes up.
      enableHaptic: false,
      child: InkWell(
        onTap: enabled
            ? () async {
                final picked = await pickDay(
                  context,
                  initial: _initial,
                  first: first,
                  last: last,
                  helpText: helpText ?? label,
                );
                if (picked != null) onChanged(picked);
              }
            : null,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
            suffixIconColor: palette.secondary,
          ),
          child: Text(
            shortDate(day),
            style: AppType.body.copyWith(color: palette.text),
          ),
        ),
      ),
    );
  }
}

/// The app's themed day picker, for a sheet that opens one straight from a link
/// (a `Not that date?` link) instead of from a field.
///
/// [helpText] is the picker's title, in the owner's words. [initial] is clamped
/// into `first..last`. Fires [Haptics.sheet] on arrival and [Haptics.select] on
/// a chosen day; `null` when dismissed.
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? helpText,
}) async {
  final day = DateTime(initial.year, initial.month, initial.day);
  // A modal surface is arriving.
  Haptics.sheet();
  final picked = await showDatePicker(
    context: context,
    initialDate: day.isBefore(first) ? first : (day.isAfter(last) ? last : day),
    firstDate: first,
    lastDate: last,
    helpText: helpText,
    cancelText: 'Cancel',
    confirmText: 'Set date',
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(datePickerTheme: _pickerTheme(context)),
      child: child!,
    ),
  );
  if (picked == null) return null;
  // A discrete value moved: the picker's one haptic.
  Haptics.select();
  return DateTime(picked.year, picked.month, picked.day);
}

/// The picker, wearing this app's surface, radius, type and accent instead of
/// the framework's grey M3 defaults.
DatePickerThemeData _pickerTheme(BuildContext context) {
  final p = context.palette;
  final onDay = WidgetStateProperty.resolveWith<Color?>(
    (states) => states.contains(WidgetState.selected) ? p.onAccent : p.text,
  );
  final dayFill = WidgetStateProperty.resolveWith<Color?>(
    (states) => states.contains(WidgetState.selected) ? p.accent : null,
  );
  return DatePickerThemeData(
    backgroundColor: p.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sheet),
      side: BorderSide(color: p.border),
    ),
    headerBackgroundColor: p.surface,
    headerForegroundColor: p.text,
    headerHelpStyle: AppType.caption.copyWith(color: p.secondary),
    dividerColor: p.border,
    weekdayStyle: AppType.caption.copyWith(color: p.secondary),
    dayStyle: AppType.body.copyWith(color: p.text),
    dayForegroundColor: onDay,
    dayBackgroundColor: dayFill,
    todayForegroundColor: WidgetStatePropertyAll<Color?>(p.accentText),
    todayBorder: BorderSide(color: p.accentText),
    yearStyle: AppType.body.copyWith(color: p.text),
    yearForegroundColor: onDay,
    yearBackgroundColor: dayFill,
    cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.accentText),
    confirmButtonStyle: TextButton.styleFrom(foregroundColor: p.accentText),
  );
}
