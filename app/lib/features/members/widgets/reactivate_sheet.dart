/// Reactivate sheet: start a new subscription from today, on the same running
/// tab (ADR-0003).
///
/// The member stopped coming and now he is back. Reactivating appends a new
/// stretch from **today** with a fresh plan snapshot (price overridable) and
/// records whatever he hands over with it. The idle days between the last day
/// he came and today are never billed — which is exactly why this opens a new
/// stretch instead of reopening the old one — and what he already owed stays
/// owed, so the sheet says so before the owner commits.
///
/// Chrome is the shared [AppSheet]; the CTA commits with the success haptic and
/// `Reactivated today`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../providers/members_providers.dart';
import 'money_text.dart';
import 'plan_choice.dart';
import 'rupee_field.dart';

class ReactivateSheet extends ConsumerStatefulWidget {
  const ReactivateSheet({
    super.key,
    required this.gymId,
    required this.memberId,
    this.memberName,
    this.pending = 0,
  });

  final String gymId;
  final String memberId;
  final String? memberName;

  /// What he still owes (₹, negative = advance) — it stays on his record.
  final int pending;

  @override
  ConsumerState<ReactivateSheet> createState() => _ReactivateSheetState();
}

class _ReactivateSheetState extends ConsumerState<ReactivateSheet> {
  final _price = TextEditingController();
  final _received = TextEditingController();
  PlanOption? _plan;
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _received.dispose();
    super.dispose();
  }

  /// What he still owes, said the owner's way; null when the tab is clear.
  String? get _owedLabel {
    if (widget.pending > 0) return '${rupees(widget.pending)} pending';
    if (widget.pending < 0) return '${rupees(-widget.pending)} advance';
    return null;
  }

  void _choosePlan(PlanOption plan) {
    setState(() {
      _plan = plan;
      // The plan's price, and that amount received now, unless the owner says
      // otherwise — 0 is allowed.
      _price.text = '${plan.amount.round()}';
      _received.text = '${plan.amount.round()}';
    });
  }

  Future<void> _reactivate() async {
    final plan = _plan;
    if (plan == null) {
      Haptics.error();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choose a plan.')));
      return;
    }
    setState(() => _saving = true);
    final price = rupeesOf(_price.text);
    final received = rupeesOf(_received.text);
    try {
      await ref.read(membersRepositoryProvider).reactivateMembership(
            gymId: widget.gymId,
            memberId: widget.memberId,
            planId: plan.id,
            priceOverride:
                (price == null || price == plan.amount.round()) ? null : price,
            firstPayment: (received ?? 0) > 0 ? received : null,
          );
      invalidateMemberViews(ref,
          gymId: widget.gymId, memberId: widget.memberId);
      Haptics.success();
      if (!mounted) return;
      // Captured before the pop so the confirmation outlives this route.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Reactivated today')));
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't reactivate this member. "
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
    final owed = _owedLabel;
    return AppSheet(
      title: 'Reactivate',
      subtitle: widget.memberName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: Text(
              'A new subscription starts today. The days he was away are not '
              'billed.',
              style: AppType.caption.copyWith(color: palette.secondary),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 1,
            child: GymPlanPicker(
              gymId: widget.gymId,
              selectedId: _plan?.id,
              onSelected: _choosePlan,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 2,
            child: RupeeField(
              controller: _price,
              label: 'Price',
              enabled: !_saving,
              helperText: 'Defaults to the plan\'s price.',
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 3,
            child: RupeeField(
              controller: _received,
              label: 'Received now',
              enabled: !_saving,
              helperText: 'Leave 0 if he paid nothing today.',
            ),
          ),
          if (owed != null) ...[
            const SizedBox(height: AppSpace.sm),
            StaggeredEntrance(
              index: 4,
              child: Text(
                '$owed stays on his record.',
                style: AppType.caption.copyWith(color: palette.secondary),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 5,
            child: SizedBox(
              height: 48,
              child: TapScale(
                enabled: !_saving,
                // The commit's success haptic is the confirmation.
                enableHaptic: false,
                child: FilledButton(
                  onPressed: _saving ? null : _reactivate,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reactivate'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
