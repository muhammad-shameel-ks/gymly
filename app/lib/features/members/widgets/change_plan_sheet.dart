/// Change-plan sheet: queue a switch to another plan at a cycle boundary
/// (ADR-0003).
///
/// The change is written as two rows the moment the owner confirms — the
/// running subscription ends at the boundary and the new one starts there — and
/// until that day arrives the record shows it as the queued switch with Undo.
/// So the sheet's job is to say exactly when the new plan starts and let the
/// owner move that day when the member asked on a different one:
///
/// - `New plan starts 12 Dec — after his current plan ends`, from
///   `planChangeBoundary` (never inside the cycle running today);
/// - a `Not that date?` link opens the picker titled `He asked to switch on`
///   (defaults to today, never the future) and the line recomputes;
/// - the plan comes from the gym's plans, and `Price` overrides the plan's
///   amount for this member only.
///
/// Chrome is the shared [AppSheet]; the CTA commits with the success haptic and
/// `Plan change scheduled for 12 Oct`.
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
import 'plan_choice.dart';
import 'rupee_field.dart';

class ChangePlanSheet extends ConsumerStatefulWidget {
  const ChangePlanSheet({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.inForce,
    this.memberName,
  });

  final String gymId;
  final String memberId;

  /// The stretch running today — the one the boundary is measured against.
  final Subscription inForce;

  final String? memberName;

  @override
  ConsumerState<ChangePlanSheet> createState() => _ChangePlanSheetState();
}

class _ChangePlanSheetState extends ConsumerState<ChangePlanSheet> {
  final _price = TextEditingController();
  PlanOption? _plan;
  late DateTime _requestedOn;
  bool _asked = false;
  bool _saving = false;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    // Today by default, never the future.
    _requestedOn = _dayOf(DateTime.now());
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  DateTime get _today => _dayOf(DateTime.now());

  /// The day the new plan starts: the first monthly boundary on or after the day
  /// he asked, never inside the cycle running today.
  DateTime get _boundary => planChangeBoundary(
        inForce: widget.inForce,
        requestedOn: _requestedOn,
        today: _today,
      );

  Future<void> _pickRequestedOn() async {
    final picked = await pickDay(
      context,
      initial: _requestedOn,
      first: widget.inForce.startDate,
      last: _today,
      helpText: 'He asked to switch on',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _requestedOn = picked;
      _asked = true;
    });
  }

  void _choosePlan(PlanOption plan) {
    setState(() {
      _plan = plan;
      // The plan's own price is the price unless the owner changes it.
      _price.text = '${plan.amount.round()}';
    });
  }

  Future<void> _save() async {
    final plan = _plan;
    if (plan == null) {
      Haptics.error();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choose a plan.')));
      return;
    }
    setState(() => _saving = true);
    final entered = rupeesOf(_price.text);
    try {
      final inserted = await ref.read(membersRepositoryProvider).changePlan(
            inForce: widget.inForce,
            planId: plan.id,
            requestedOn: _requestedOn,
            priceOverride:
                (entered == null || entered == plan.amount.round()) ? null : entered,
          );
      invalidateMemberViews(ref,
          gymId: widget.gymId, memberId: widget.memberId);
      Haptics.success();
      if (!mounted) return;
      // Captured before the pop so the confirmation outlives this route.
      final messenger = ScaffoldMessenger.of(context);
      final message =
          'Plan change scheduled for ${shortDate(inserted.startDate)}';
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't change the plan. "
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
    final caption = AppType.caption.copyWith(color: palette.secondary);
    return AppSheet(
      title: 'Change plan',
      subtitle: widget.memberName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: GymPlanPicker(
              gymId: widget.gymId,
              selectedId: _plan?.id,
              onSelected: _choosePlan,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 1,
            child: RupeeField(
              controller: _price,
              label: 'Price',
              enabled: !_saving,
              helperText: 'Defaults to the plan\'s price.',
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
                    'New plan starts ${shortDate(_boundary)} — '
                    'after his current plan ends',
                    style: AppType.body.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_asked) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'He asked to switch on ${shortDate(_requestedOn)}',
                      style: caption,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: StaggeredEntrance(
              index: 3,
              child: TapScale(
                enabled: !_saving,
                // The picker fires Haptics.sheet() itself when it comes up.
                enableHaptic: false,
                child: TextButton(
                  onPressed: _saving ? null : _pickRequestedOn,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.accentText,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Not that date?'),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 4,
            child: SizedBox(
              height: 48,
              child: TapScale(
                enabled: !_saving,
                // The commit's success haptic is the confirmation.
                enableHaptic: false,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change plan'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
