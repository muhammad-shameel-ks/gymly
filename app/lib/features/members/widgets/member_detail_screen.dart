/// Member detail: current subscription + full history (desc) + Renew.
///
/// Renew appends a subscription row (ADR-0001) — history rows are never
/// updated by it. The one edit to a row is a start-date correction (ADR-0002),
/// offered from the current subscription card. Renew/Call/WhatsApp actions sit
/// in the thumb zone, and reaching the member goes through [ContactLauncher] so
/// every contact action in the app behaves the same. The header carries the
/// signature [DueRing] around the member's initials, the current subscription
/// signals its own state change, and the history staggers in once per visit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/contact/contact_launcher.dart';
import '../../../core/motion/motion.dart';
import '../../../core/signature/signature.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../models/member.dart';
import '../providers/members_providers.dart';
import 'adjust_start_sheet.dart';
import 'due_cue.dart';
import 'member_form_sheet.dart';
import 'member_states.dart';
import 'renew_sheet.dart';

final _dayMonth = DateFormat('d MMM');
final _inr = NumberFormat.decimalPattern('en_IN');

/// `₹3,333` while [rolling] settles: Indian grouping, and the precision of the
/// target so the label never changes shape mid-roll.
String _amountLabel(num amount, double rolling) {
  final whole = amount.remainder(1) == 0;
  return '₹${_inr.format(whole ? rolling.round() : rolling)}';
}

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.gymId,
    required this.memberId,
  });

  final String gymId;
  final String memberId;

  String _fmt(DateTime d) => _dayMonth.format(d);

  /// What the header ring encodes, said the way an owner says it: how much
  /// time is left, not the share of the period consumed. The ring keeps the
  /// precise number (its semantics label reports the percentage).
  String _periodLine(Subscription? c) {
    if (c == null) return 'No subscription yet';
    final days = c.daysToExpiry();
    if (days < 0) {
      final lapsed = -days;
      return lapsed == 1 ? 'Lapsed yesterday' : 'Lapsed $lapsed days ago';
    }
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  void _openRenew(BuildContext context, MemberWithDues d) {
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => RenewSheet(
        gymId: gymId,
        memberId: memberId,
        current: d.current,
      ),
    );
  }

  void _openEdit(BuildContext context, MemberWithDues d) {
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => MemberFormSheet(gymId: gymId, existing: d.member),
    );
  }

  /// Correction entry point (ADR-0002). Only reachable for a subscription that
  /// carries a plan, since the period is recomputed from its `duration_days`.
  void _openAdjust(BuildContext context, Subscription sub) {
    final days = sub.planDurationDays;
    if (sub.planId == null || days == null) return;
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => AdjustStartSheet(
        gymId: gymId,
        memberId: sub.memberId,
        membershipId: sub.id,
        currentStart: sub.startDate,
        durationDays: days,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(memberDetailProvider(memberId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member'),
        actions: [
          TapScale(
            child: IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit member',
              onPressed: () {
                final d = detail.value;
                if (d == null) return;
                _openEdit(context, d);
              },
            ),
          ),
        ],
      ),
      body: detail.when(
        skipLoadingOnReload: true,
        loading: () => const MemberListSkeleton(rows: 4),
        error: (_, _) => MemberError(
          title: "Couldn't load this member",
          onRetry: () => ref.invalidate(memberDetailProvider(memberId)),
        ),
        data: (d) {
          final c = d.current;
          final palette = context.palette;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                StaggeredEntrance(
                  index: 0,
                  child: Row(
                    children: [
                      MemberAvatar(entry: d, size: 66),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.member.name,
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              d.member.phone,
                              style: TextStyle(
                                color: palette.secondary,
                                fontSize: 16,
                              ),
                            ),
                            if ((d.member.note ?? '').isNotEmpty)
                              Text(
                                d.member.note!,
                                style: TextStyle(
                                  color: palette.secondary,
                                  fontSize: 13,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              _periodLine(c),
                              style: TextStyle(
                                color: palette.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                StaggeredEntrance(
                  index: 1,
                  child: Text(
                    'Current subscription',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                StaggeredEntrance(
                  index: 2,
                  child: c == null
                      ? const _NoSubscriptionCard()
                      : _SubscriptionCard(
                          sub: c,
                          current: true,
                          fmt: _fmt,
                          onAdjustStart:
                              c.planId != null && c.planDurationDays != null
                                  ? () => _openAdjust(context, c)
                                  : null,
                        ),
                ),
                const SizedBox(height: 24),
                StaggeredEntrance(
                  index: 3,
                  child: Text(
                    'History',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (d.history.isEmpty)
                  Text(
                    'Your first renewal appears here.',
                    style: TextStyle(
                        color: palette.secondary, fontSize: 16),
                  )
                else
                  ...d.history.indexed.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: StaggeredEntrance(
                        index: 4 + e.$1,
                        child: _SubscriptionCard(
                          sub: e.$2,
                          current: false,
                          fmt: _fmt,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomSheet: detail.maybeWhen(
        data: (d) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TapScale(
                      // The renewal sheet haptics when it arrives.
                      enableHaptic: false,
                      child: FilledButton(
                        onPressed: () => _openRenew(context, d),
                        child: const Text('Renew'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: TapScale(
                    // The launcher fires the tap haptic itself.
                    enableHaptic: false,
                    child: OutlinedButton(
                      onPressed: () =>
                          ContactLauncher.call(context, d.member.phone),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Icon(Icons.call),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: TapScale(
                    // The launcher fires the tap haptic itself.
                    enableHaptic: false,
                    child: OutlinedButton(
                      onPressed: () =>
                          ContactLauncher.openWhatsApp(context, d.member.phone),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Icon(Icons.chat),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _NoSubscriptionCard extends StatelessWidget {
  const _NoSubscriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        "Renew to start this member's first subscription.",
        style: TextStyle(color: context.palette.secondary, fontSize: 16),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.sub,
    required this.current,
    required this.fmt,
    this.onAdjustStart,
  });

  final Subscription sub;
  final bool current;
  final String Function(DateTime) fmt;

  /// Start-date correction (ADR-0002) for the active subscription. Null — for
  /// history rows, and for the active row when its plan is missing (no period
  /// length to recompute the due date from) — hides the control.
  final VoidCallback? onAdjustStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bucket = sub.bucket();
    final status = dueTextColor(palette, bucket);
    final amount = sub.planAmount;
    final days = sub.planDurationDays;
    final term = days == null
        ? null
        : (days == 1 ? '1 day' : '$days days');
    final caption = TextStyle(color: palette.secondary, fontSize: 13);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current ? status : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Springs once when the bucket changes — i.e. when a renewal lands.
              AnimatedStatusDot(color: status, statusKey: bucket),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.planName ?? 'Subscription',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${fmt(sub.startDate)} → ${fmt(sub.expiryDate)}',
                      style: caption,
                    ),
                    if (amount != null)
                      Row(
                        children: [
                          AnimatedAmount(
                            amount: amount.toDouble(),
                            initialAmount: amount.toDouble(),
                            animate: current,
                            formatter: (v) => _amountLabel(amount, v),
                            style: caption,
                          ),
                          if (term != null)
                            Expanded(
                              child: Text(
                                ' · $term',
                                style: caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      )
                    else if (term != null)
                      Text(term, style: caption),
                  ],
                ),
              ),
              if (current)
                Text(
                  bucket.label,
                  style: TextStyle(
                    color: status,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (onAdjustStart != null) ...[
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TapScale(
                // The correction sheet fires Haptics.sheet() when it arrives.
                enableHaptic: false,
                child: TextButton.icon(
                  onPressed: onAdjustStart,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                    ),
                    foregroundColor: palette.accentText,
                  ),
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Adjust start date'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
