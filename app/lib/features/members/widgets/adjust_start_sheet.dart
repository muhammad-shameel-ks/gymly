/// Adjust start date sheet: correct the active subscription's dates in place
/// (ADR-0002 — **not** a renewal).
///
/// Owners migrate members who joined before the app did, so the entered date —
/// and with it the due date — is wrong. Renewal stays append-only (ADR-0001);
/// this rewrites the active `memberships` row, so the sheet says what changes
/// before saving, previews the resulting due date live, and refuses a date the
/// plan cannot back (no period length) or one absurdly far ahead. Chrome is the
/// shared [AppSheet], the picker is the themed Material one, and the CTA
/// carries its busy state in-button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../providers/members_providers.dart';

final _dayMonth = DateFormat('d MMM');

/// How far ahead a start date may sit before it is read as a typo.
const _maxAheadYears = 2;

class AdjustStartSheet extends ConsumerStatefulWidget {
  const AdjustStartSheet({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.membershipId,
    required this.currentStart,
    required this.durationDays,
  });

  final String gymId;
  final String memberId;

  /// The active subscription row to rewrite (a member's latest-expiry row).
  final String membershipId;

  /// What the row says today, so the owner sees what is being replaced.
  final DateTime currentStart;

  /// Period length of the row's plan, mirrored from the read embed. The
  /// repository re-reads `plans.duration_days` authoritatively when saving.
  final int durationDays;

  @override
  ConsumerState<AdjustStartSheet> createState() => _AdjustStartSheetState();
}

class _AdjustStartSheetState extends ConsumerState<AdjustStartSheet> {
  late DateTime _start;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _start = _dayOf(widget.currentStart);
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmt(DateTime d) => _dayMonth.format(d);

  DateTime get _today => _dayOf(DateTime.now());

  /// Old members can predate the app by years.
  DateTime get _first => DateTime(2000);

  /// A start date years ahead is a typo, not a migration.
  DateTime get _last =>
      DateTime(_today.year + _maxAheadYears, _today.month, _today.day);

  DateTime get _expiry => _start.add(Duration(days: widget.durationDays));

  /// Refusal copy for the current choice, or null when it can be saved.
  ///
  /// The picker cannot express a plan with no length, so the guard is repeated
  /// here; the bounds are re-checked too, so the CTA never writes a date the
  /// picker could not have produced.
  String? get _refusal {
    if (widget.durationDays < 1) {
      return 'This plan has no duration. Set one in Plans, then try again.';
    }
    if (_start.isAfter(_last)) {
      return 'Pick a start date within $_maxAheadYears years.';
    }
    if (!_expiry.isAfter(_start)) {
      return 'Pick a start date that ends after it starts.';
    }
    return null;
  }

  /// Opens the themed Material date picker inside the app's dialog chrome.
  Future<void> _pickDate() async {
    Haptics.sheet();
    final initial = _start.isBefore(_first)
        ? _first
        : (_start.isAfter(_last) ? _last : _start);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _first,
      lastDate: _last,
      helpText: 'Start date',
      cancelText: 'Cancel',
      confirmText: 'Set date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(datePickerTheme: _pickerTheme(context)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    Haptics.select();
    setState(() => _start = _dayOf(picked));
  }

  /// The picker, wearing this app's surface, radius, type and accent instead
  /// of the framework's grey M3 defaults.
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

  Future<void> _save() async {
    final refusal = _refusal;
    if (refusal != null) {
      Haptics.error();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(refusal)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(membersRepositoryProvider).correctStartDate(
            membershipId: widget.membershipId,
            startDate: _start,
          );
      invalidateMemberViews(ref,
          gymId: widget.gymId, memberId: widget.memberId);
      Haptics.success();
      if (!mounted) return;
      // Built before the pop so the confirmation outlives this route; the
      // messenger is the app-level one, so the SnackBar lands on the screen
      // underneath.
      final message =
          'Start date set to ${_fmt(_start)} · due ${_fmt(_expiry)}';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't save the start date. "
              'Check your connection, then try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = TextStyle(color: palette.secondary, fontSize: 13);
    return AppSheet(
      title: 'Adjust start date',
      subtitle: 'Corrects the current subscription in place. '
          'The old dates are replaced.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: Text(
              'Current start date ${_fmt(widget.currentStart)}',
              style: caption,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 1,
            child: TapScale(
              enabled: !_saving,
              // The picker fires Haptics.sheet() when it comes up.
              enableHaptic: false,
              child: InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Start date',
                    suffixIcon: const Icon(Icons.calendar_today, size: 20),
                    suffixIconColor: palette.secondary,
                  ),
                  child: Text(
                    _fmt(_start),
                    style: AppType.body.copyWith(color: palette.text),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 2,
            child: Text(
              '${_fmt(_start)} → due ${_fmt(_expiry)}',
              style: AppType.body.copyWith(color: palette.text),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 3,
            child: SizedBox(
              height: 48,
              child: TapScale(
                enabled: !_saving,
                // The save commits, and the confirmation is the success haptic
                // plus the SnackBar — nothing here adds a second press haptic.
                enableHaptic: false,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
