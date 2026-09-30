/// Adjust start date sheet: correct the start date of the stretch in force, in
/// place (ADR-0002, amended by ADR-0003).
///
/// Owners migrate members who joined before the app did, so the entered day is
/// often wrong. A correction is the one in-place edit a stretch allows: it
/// rewrites `start_date` and nothing else. There is no stored end date to
/// recompute and no plan length to lean on — the clock that bills him and the
/// monthly deadlines both derive from that date at read time, which is why the
/// sheet says the new day and lets the record show the rest.
///
/// The day can be any real past start (the picker never offers tomorrow): an
/// entered start date is today or earlier by definition. Chrome is the shared
/// [AppSheet], the picker is [DayField]'s, and the CTA commits with the success
/// haptic plus `Start date set to 12 Sep`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../providers/members_providers.dart';
import 'day_field.dart';
import 'money_text.dart';

class AdjustStartSheet extends ConsumerStatefulWidget {
  const AdjustStartSheet({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.membershipId,
    required this.currentStart,
  });

  final String gymId;
  final String memberId;

  /// The stretch row to rewrite (the one in force).
  final String membershipId;

  /// What the row says today, so the owner sees what is being replaced.
  final DateTime currentStart;

  @override
  ConsumerState<AdjustStartSheet> createState() => _AdjustStartSheetState();
}

class _AdjustStartSheetState extends ConsumerState<AdjustStartSheet> {
  late DateTime _start;
  bool _saving = false;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _start = _dayOf(widget.currentStart);
  }

  DateTime get _today => _dayOf(DateTime.now());

  /// Old members can predate the app by years.
  DateTime get _first => DateTime(2000);

  Future<void> _save() async {
    if (_start.isAfter(_today)) return;
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
      // Built before the pop so the confirmation outlives this route.
      final messenger = ScaffoldMessenger.of(context);
      final message = 'Start date set to ${shortDate(_start)}';
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
    return AppSheet(
      title: 'Adjust start date',
      subtitle: 'Corrects the current subscription in place. '
          'The old start date is replaced.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: Text(
              'Current start date ${shortDate(widget.currentStart)}',
              style: AppType.caption.copyWith(color: palette.secondary),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 1,
            child: DayField(
              label: 'Start date',
              day: _start,
              first: _first,
              // A member cannot have started tomorrow.
              last: _today,
              enabled: !_saving,
              onChanged: (d) => setState(() => _start = d),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 2,
            child: Text(
              'Starts ${shortDate(_start)}',
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
