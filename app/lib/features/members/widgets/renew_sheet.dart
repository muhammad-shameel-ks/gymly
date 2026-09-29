/// Renew sheet: pick a plan and append a subscription row (ADR-0001).
///
/// Start = old expiry when still active, else today; expiry = start +
/// plan days. The repository never updates history rows. The success haptic
/// fires on the insert; a missing plan or a failed insert is refused with the
/// error haptic. Content staggers in once per open and the CTA carries its
/// busy state in-button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../models/member.dart';
import '../providers/members_providers.dart';

final _dayMonth = DateFormat('d MMM');

class RenewSheet extends ConsumerStatefulWidget {
  const RenewSheet({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.current,
  });

  final String gymId;
  final String memberId;

  /// Latest-expiry subscription, if any (drives the start-date preview).
  final Subscription? current;

  @override
  ConsumerState<RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends ConsumerState<RenewSheet> {
  String? _planId;
  bool _saving = false;

  String _fmt(DateTime d) => _dayMonth.format(d);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// True while [RenewSheet.current] still runs, so the renewal continues from
  /// its expiry instead of starting today.
  bool get _continues {
    final expiry = widget.current?.expiryDate;
    if (expiry == null) return false;
    return !DateTime(expiry.year, expiry.month, expiry.day).isBefore(_today);
  }

  /// Preview of the new period for the selected plan.
  String _preview(PlanOption plan) {
    final old = widget.current?.expiryDate;
    final start = _continues
        ? DateTime(old!.year, old.month, old.day)
        : _today;
    final expiry = start.add(Duration(days: plan.durationDays));
    return '${_fmt(start)} → ${_fmt(expiry)}';
  }

  Future<void> _renew() async {
    if (_planId == null) {
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a plan to renew.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(membersRepositoryProvider).renew(
            gymId: widget.gymId,
            memberId: widget.memberId,
            planId: _planId!,
          );
      invalidateMemberViews(ref,
          gymId: widget.gymId, memberId: widget.memberId);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't renew. Check your connection, then try again.",
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
    final plans = ref.watch(plansForGymProvider(widget.gymId));
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Text(
                'Renew subscription',
                style: TextStyle(
                  color: context.palette.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            StaggeredEntrance(
              index: 1,
              child: Text(
                _continues
                    ? 'Renewal continues from '
                        '${_fmt(widget.current!.expiryDate)}.'
                    : 'Renewal starts today.',
                style: TextStyle(
                    color: context.palette.secondary, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            StaggeredEntrance(
              index: 2,
              child: plans.when(
                loading: () => const Shimmer(
                  child: ShimmerBox(height: 56),
                ),
                error: (_, _) => Text(
                  "Couldn't load plans. Check your connection, then try again.",
                  style: TextStyle(
                      color: context.palette.error, fontSize: 16),
                ),
                data: (ps) {
                  if (ps.isEmpty) {
                    return Text(
                      'Add a plan to renew.',
                      style: TextStyle(
                          color: context.palette.secondary, fontSize: 16),
                    );
                  }
                  final selected = ps.where((p) => p.id == _planId);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _planId,
                        decoration: const InputDecoration(
                          labelText: 'Plan',
                        ),
                        items: [
                          for (final p in ps)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.label),
                            ),
                        ],
                        onChanged: (v) {
                          Haptics.select();
                          setState(() => _planId = v);
                        },
                      ),
                      if (selected.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'New period: ${_preview(selected.first)}',
                          style: TextStyle(
                            color: context.palette.secondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            StaggeredEntrance(
              index: 3,
              child: SizedBox(
                height: 48,
                child: TapScale(
                  enabled: !_saving,
                  enableHaptic: false,
                  child: FilledButton(
                    onPressed: _saving ? null : _renew,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Renew'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
