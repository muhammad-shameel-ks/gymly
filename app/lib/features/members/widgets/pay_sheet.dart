/// Pay sheet — the one payment surface of the app (DESIGN.md §3, §4).
///
/// ## The one exported entry point
///
/// [showPaySheet] is how every surface reaches this sheet:
///
/// ```dart
/// Haptics.sheet(); // the caller fires the arrival haptic — one gesture, one
/// await showPaySheet(context, gymId: e.member.gymId, memberId: e.member.id,
///     pending: e.tab.pending, dueNow: e.tab.dueNow);
/// ```
///
/// The caller passes the member and his running amount; the sheet pre-fills the
/// full pending amount, records it through `recordPayment`, refreshes every
/// affected view (`invalidateMemberViews` already invalidates the Home feed)
/// and shows `Payment recorded`. The caller invalidates nothing and reads no
/// result. Pass [existing] to open the same fields over a receipt the owner
/// wants to correct: the save calls `updatePayment` (`Payment updated`) and the
/// sheet offers [DeletePaymentSheet] (`Payment deleted`) behind a confirmation,
/// because a typo is not payment history (ADR-0003).
///
/// Fields (voice.md): `Amount` · `Paid on` · `Note (optional)`, the day never in
/// the future, the amount never 0. Chrome is the shared [AppSheet], every write
/// is haptically confirmed, and the CTA carries its busy state in-button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../models/payment.dart';
import '../providers/members_providers.dart';
import 'day_field.dart';
import 'money_text.dart';
import 'rupee_field.dart';

/// Opens the payment sheet. See the library doc: the **one** entry point.
///
/// [pending] is the member's running amount in ₹ — the tab this payment lands
/// on. [dueNow] is what he owes *now* (the instalments he is behind on, ₹) and
/// it is what the amount field pre-fills: the desk collects the month he is on,
/// not the whole plan, and the owner raises it for the rest. [existing] corrects
/// a recorded receipt instead of recording a new one.
Future<void> showPaySheet(
  BuildContext context, {
  required String gymId,
  required String memberId,
  int pending = 0,
  int dueNow = 0,
  Payment? existing,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => PaySheet(
      gymId: gymId,
      memberId: memberId,
      pending: pending,
      dueNow: dueNow,
      existing: existing,
    ),
  );
}

class PaySheet extends ConsumerStatefulWidget {
  const PaySheet({
    super.key,
    required this.gymId,
    required this.memberId,
    this.pending = 0,
    this.dueNow = 0,
    this.existing,
  });

  final String gymId;
  final String memberId;

  /// The member's running amount (₹, negative = advance) — shown as the tab the
  /// payment lands on.
  final int pending;

  /// What he owes now, in ₹: pre-fills the field, so the default is the
  /// instalment he is behind on rather than the whole plan.
  final int dueNow;

  /// The receipt being corrected, or null to record a new one.
  final Payment? existing;

  @override
  ConsumerState<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<PaySheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _day;
  bool _saving = false;
  String? _amountError;

  bool get _editing => widget.existing != null;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    // What he owes now is the default; a tab with nothing behind (paid up, or
    // paid ahead) starts empty rather than at 0.
    _amount = TextEditingController(
      text: existing != null
          ? '${existing.amount}'
          : (widget.dueNow > 0 ? '${widget.dueNow}' : ''),
    );
    _note = TextEditingController(text: existing?.note ?? '');
    // Today by default, never the future.
    _day = existing?.paidOn ?? _dayOf(DateTime.now());
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime get _today => _dayOf(DateTime.now());

  /// `₹2,267 pending` / `₹500 advance` — the tab this payment lands on.
  String? get _pendingLine {
    if (widget.pending > 0) return '${rupees(widget.pending)} pending';
    if (widget.pending < 0) return '${rupees(-widget.pending)} advance';
    return null;
  }

  String? _amountErrorFor(String? raw) {
    final amount = rupeesOf(raw ?? '');
    if (amount == null || amount < 1) return 'Enter the amount he paid.';
    return null;
  }

  Future<void> _save() async {
    final error = _amountErrorFor(_amount.text);
    if (error != null || _day.isAfter(_today)) {
      Haptics.error();
      setState(() => _amountError = error);
      return;
    }
    setState(() {
      _amountError = null;
      _saving = true;
    });
    final repo = ref.read(membersRepositoryProvider);
    final existing = widget.existing;
    try {
      if (existing == null) {
        await repo.recordPayment(
          gymId: widget.gymId,
          memberId: widget.memberId,
          amount: rupeesOf(_amount.text)!,
          paidOn: _day,
          note: _note.text,
        );
      } else {
        await repo.updatePayment(
          id: existing.id,
          amount: rupeesOf(_amount.text)!,
          paidOn: _day,
          note: _note.text,
        );
      }
      invalidateMemberViews(ref,
          gymId: widget.gymId, memberId: widget.memberId);
      Haptics.success();
      if (!mounted) return;
      // Captured before the pop so the confirmation outlives this route.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(existing == null ? 'Payment recorded' : 'Payment updated')),
      );
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null
                  ? "Couldn't record the payment. "
                      'Check your connection, then try again.'
                  : "Couldn't save the payment. "
                      'Check your connection, then try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (_) => DeletePaymentSheet(payment: existing),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(membersRepositoryProvider).deletePayment(existing.id);
      invalidateMemberViews(ref,
          gymId: widget.gymId, memberId: widget.memberId);
      Haptics.success();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Payment deleted')));
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't delete this payment. "
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
    final existing = widget.existing;
    return AppSheet(
      title: _editing ? 'Edit payment' : 'Record payment',
      subtitle: _editing ? 'Recorded ${shortDate(existing!.paidOn)}' : _pendingLine,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: RupeeField(
              controller: _amount,
              label: 'Amount',
              autofocus: !_editing,
              enabled: !_saving,
              validator: _amountErrorFor,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
            ),
          ),
          if (_amountError != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              _amountError!,
              style: AppType.caption.copyWith(color: palette.error),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 1,
            child: DayField(
              label: 'Paid on',
              day: _day,
              // Money cannot arrive tomorrow.
              first: DateTime(2000),
              last: _today,
              enabled: !_saving,
              onChanged: (d) => setState(() => _day = d),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 2,
            child: TextFormField(
              controller: _note,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 3,
            child: SizedBox(
              height: 48,
              child: TapScale(
                enabled: !_saving,
                // The save commits; its success haptic is the confirmation.
                enableHaptic: false,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editing ? 'Save payment' : 'Record payment'),
                ),
              ),
            ),
          ),
          if (_editing) ...[
            const SizedBox(height: AppSpace.xs),
            StaggeredEntrance(
              index: 4,
              child: SizedBox(
                height: 48,
                child: TapScale(
                  enabled: !_saving,
                  // The confirmation sheet arriving is the visible change.
                  enableHaptic: false,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: palette.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete payment'),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `Delete payment?` — the confirmation a receipt needs before it is removed.
///
/// Pops `true` when the owner confirms. Reached from the pay sheet's edit mode
/// (and anything else that must remove a receipt), never straight off a swipe.
class DeletePaymentSheet extends StatelessWidget {
  const DeletePaymentSheet({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSheet(
      title: 'Delete payment?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: Text(
              '${rupees(payment.amount)} recorded on '
              '${shortDate(payment.paidOn)} will be removed.',
              style: AppType.body.copyWith(color: palette.text),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 1,
            child: Text(
              'He may show as overdue again.',
              style: AppType.caption.copyWith(color: palette.secondary),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TapScale(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TapScale(
                      // The delete itself fires the success/error haptic.
                      enableHaptic: false,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.error,
                          foregroundColor: palette.onAccent,
                        ),
                        child: const Text('Delete payment'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
