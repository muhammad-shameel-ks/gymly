/// Cancel sheet: stop the clock on the last day he came (ADR-0003).
///
/// The date the owner enters becomes the subscription's end date; what he
/// already owes stays owed and an overpayment stays an advance. The preview is
/// the whole point of the sheet, so it is live: `payableTo` recomputes what the
/// tab settles for on the chosen day and the sheet says it the owner's way —
/// `Payable to 12 Sep — ₹2,000`, `40 of 90 days` — beside what he has already
/// paid and what that leaves pending (or in advance).
///
/// The picker never offers a future day: the member cannot have come tomorrow.
/// Chrome is the shared [AppSheet] and the confirm commits with the success
/// haptic plus `Cancelled on 12 Sep`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../domain/member_money.dart';
import '../models/member.dart';
import '../providers/members_providers.dart';
import 'day_field.dart';
import 'money_text.dart';

class CancelSheet extends ConsumerStatefulWidget {
  const CancelSheet({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.memberName,
    required this.stretch,
    required this.stretches,
    required this.paid,
  });

  final String gymId;
  final String memberId;
  final String memberName;

  /// The stretch in force — the row this writes `ended_on` to.
  final Subscription stretch;

  /// Every stretch of the member, for the live payable preview.
  final List<Subscription> stretches;

  /// What he has paid so far (₹), for the resulting pending/advance.
  final int paid;

  @override
  ConsumerState<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<CancelSheet> {
  late DateTime _lastDay;
  bool _saving = false;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    // Today by default.
    _lastDay = _dayOf(DateTime.now());
  }

  DateTime get _today => _dayOf(DateTime.now());

  /// What the tab settles for on the chosen day, with the day count.
  ///
  /// A queued plan change has not started yet, so it is not part of what
  /// closing this subscription on the chosen day settles: only the stretches
  /// that have begun count towards the preview and its `n of total days`.
  PayableTo get _preview {
    final today = _today;
    return payableTo(
      stretches: [
        for (final s in widget.stretches)
          if (!_dayOf(s.startDate).isAfter(today)) s,
      ],
      date: _lastDay,
    );
  }

  /// `₹2,267 pending` / `₹500 advance` / `Nothing left to pay.` once the tab is
  /// closed on the chosen day.
  String get _outcome {
    final left = _preview.amount - widget.paid;
    if (left > 0) return '${rupees(left)} pending';
    if (left < 0) return '${rupees(-left)} advance';
    return 'Nothing left to pay.';
  }

  Future<void> _cancel() async {
    if (_lastDay.isAfter(_today)) return;
    setState(() => _saving = true);
    try {
      await ref.read(membersRepositoryProvider).cancelMembership(
            stretch: widget.stretch,
            lastDayCame: _lastDay,
          );
      invalidateMemberViews(ref,
          gymId: widget.gymId, memberId: widget.memberId);
      Haptics.success();
      if (!mounted) return;
      // Captured before the pop so the confirmation outlives this route.
      final messenger = ScaffoldMessenger.of(context);
      final message = 'Cancelled on ${shortDate(_lastDay)}';
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't cancel this member. "
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
    final preview = _preview;
    final caption = AppType.caption.copyWith(color: palette.secondary);
    return AppSheet(
      title: 'Cancel membership',
      subtitle: widget.memberName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: Text(
              'Stops on the last day he came.',
              style: caption,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 1,
            child: DayField(
              label: 'Last day he came',
              day: _lastDay,
              // He cannot have come before the plan started, nor tomorrow.
              first: widget.stretch.startDate,
              last: _today,
              enabled: !_saving,
              onChanged: (d) => setState(() => _lastDay = d),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 2,
            child: Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Payable to ${shortDate(_lastDay)} — '
                    '${rupees(preview.amount)}',
                    style: AppType.body.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${preview.days} of ${preview.totalDays} days',
                    style: caption,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text('${rupees(widget.paid)} paid so far', style: caption),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    _outcome,
                    style: caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 3,
            child: SizedBox(
              height: 48,
              child: TapScale(
                enabled: !_saving,
                // The commit's success haptic is the confirmation.
                enableHaptic: false,
                child: FilledButton(
                  onPressed: _saving ? null : _cancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.error,
                    foregroundColor: palette.onAccent,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cancel membership'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
