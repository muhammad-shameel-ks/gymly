/// Member detail: the running tab, the subscription in force, the queued plan
/// change, the payment record and the stretch history (ADR-0003).
///
/// One member's whole money story in reading order:
///
/// 1. the header, with the signature [DueRing] around his initials;
/// 2. the money card — `₹2,267 pending · due 12 Oct` or `₹500 advance`, what he
///    has received so far, and `Payable to 20 Jul` once he has stopped;
/// 3. the subscription in force (plan, price, the cycle it is inside) with the
///    `Adjust start date` correction; or, when he has stopped, `Cancelled on
///    20 Jul`; plus the queued plan change as `Switches to … · Undo`;
/// 4. every payment, tappable to correct or delete;
/// 5. every ended stretch with its end date and why it ended.
///
/// Actions sit in the thumb zone: **Pay** (the one payment sheet, shared with
/// Home), Call, WhatsApp, and **Change plan** / **Cancel** — or **Reactivate**
/// once he has stopped. Reaching the member goes through [ContactLauncher] so
/// every contact action in the app behaves the same.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contact/contact_launcher.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../domain/member_money.dart';
import '../models/member.dart';
import '../models/member_detail.dart';
import '../models/payment.dart';
import '../providers/members_providers.dart';
import 'adjust_start_sheet.dart';
import 'cancel_sheet.dart';
import 'change_plan_sheet.dart';
import 'due_cue.dart';
import 'member_form_sheet.dart';
import 'member_states.dart';
import 'pay_sheet.dart';
import 'reactivate_sheet.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.gymId,
    required this.memberId,
  });

  final String gymId;
  final String memberId;

  // ── actions ───────────────────────────────────────────────────────────────

  void _openEdit(BuildContext context, MemberDetail d) {
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => MemberFormSheet(gymId: gymId, existing: d.member),
    );
  }

  /// The one payment sheet (see `pay_sheet.dart`); [existing] corrects a
  /// receipt instead of recording a new one.
  void _openPay(BuildContext context, MemberDetail d, {Payment? existing}) {
    Haptics.sheet();
    showPaySheet(
      context,
      gymId: gymId,
      memberId: memberId,
      pending: d.tab.pending,
      dueNow: d.tab.dueNow,
      existing: existing,
    );
  }

  /// Start-date correction (ADR-0002): one in-place rewrite of the stretch in
  /// force, so the billing clock and the deadlines move with it.
  void _openAdjust(BuildContext context, Subscription sub) {
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => AdjustStartSheet(
        gymId: gymId,
        memberId: memberId,
        membershipId: sub.id,
        currentStart: sub.startDate,
      ),
    );
  }

  void _openChangePlan(BuildContext context, MemberDetail d) {
    final inForce = d.inForce;
    if (inForce == null) return;
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => ChangePlanSheet(
        gymId: gymId,
        memberId: memberId,
        inForce: inForce,
        memberName: d.member.name,
      ),
    );
  }

  void _openCancel(BuildContext context, MemberDetail d) {
    final inForce = d.inForce;
    if (inForce == null) return;
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => CancelSheet(
        gymId: gymId,
        memberId: memberId,
        memberName: d.member.name,
        stretch: inForce,
        stretches: d.stretches,
        paid: d.tab.paid,
      ),
    );
  }

  void _openReactivate(BuildContext context, MemberDetail d) {
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => ReactivateSheet(
        gymId: gymId,
        memberId: memberId,
        memberName: d.member.name,
        pending: d.tab.pending,
      ),
    );
  }

  /// The stretch a queued switch closes: the one whose last day in force is the
  /// day before the queued stretch starts. Falls back to the latest stretch
  /// closed by a plan change before that day, so a row written by an older
  /// build (or by hand) still leaves Undo working instead of dying silently.
  Subscription? _previousOfQueued(MemberDetail d) {
    final queued = d.queuedStretch;
    if (queued == null) return null;
    final start = queued.startDate;
    Subscription? exact;
    Subscription? latest;
    for (final s in d.stretches) {
      if (s.id == queued.id) continue;
      if (s.endReason != SubscriptionEnd.planChange) continue;
      final end = s.endedOn;
      if (end == null) continue;
      final dayAfter =
          DateTime(end.year, end.month, end.day + 1);
      if (dayAfter.isAtSameMomentAs(start)) exact = s;
      if (end.isBefore(start) &&
          (latest == null || s.startDate.isAfter(latest.startDate))) {
        latest = s;
      }
    }
    return exact ?? latest;
  }

  Future<void> _undoPlanChange(
    BuildContext context,
    WidgetRef ref,
    MemberDetail d,
  ) async {
    final queued = d.queuedStretch;
    final previous = _previousOfQueued(d);
    final messenger = ScaffoldMessenger.of(context);
    if (queued == null || previous == null) {
      // Never a silent no-op: a button that does nothing reads as a broken tap.
      Haptics.error();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't undo the plan change. "
            'Check your connection, then try again.',
          ),
        ),
      );
      return;
    }
    try {
      await ref.read(membersRepositoryProvider).undoPlanChange(
            insertedStretchId: queued.id,
            previousStretchId: previous.id,
          );
      invalidateMemberViews(ref, gymId: gymId, memberId: memberId);
      Haptics.success();
      messenger.showSnackBar(
        const SnackBar(content: Text('Plan change undone')),
      );
    } catch (_) {
      Haptics.error();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't undo the plan change. "
            'Check your connection, then try again.',
          ),
        ),
      );
    }
  }

  // ── body ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(memberDetailProvider(memberId));
    return Scaffold(
      backgroundColor: context.palette.bg,
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
          final palette = context.palette;
          // The moveable stretches: every ended one, newest first.
          final history = [
            for (final s in d.stretches.reversed)
              if (s.endedOn != null) s,
          ];
          var index = 0;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.sm,
                AppSpace.screen,
                // Clears the two action rows pinned to the bottom.
                140,
              ),
              children: [
                StaggeredEntrance(
                  index: index++,
                  child: _Header(detail: d),
                ),
                const SizedBox(height: AppSpace.md),
                StaggeredEntrance(index: index++, child: _MoneyCard(tab: d.tab)),
                const SizedBox(height: AppSpace.lg),
                StaggeredEntrance(
                  index: index++,
                  child: const _SectionTitle('Current subscription'),
                ),
                const SizedBox(height: AppSpace.sm),
                StaggeredEntrance(
                  index: index++,
                  child: switch (d) {
                    MemberDetail(inForce: final s?) => _InForceCard(
                        sub: s,
                        tab: d.tab,
                        onAdjustStart: () => _openAdjust(context, s),
                      ),
                    MemberDetail(cancelled: true) => _CancelledCard(
                        payableTo: d.tab.payableTo,
                      ),
                    _ => const _NoSubscriptionCard(),
                  },
                ),
                if (d.queuedStretch != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  StaggeredEntrance(
                    index: index++,
                    child: _QueuedCard(
                      queued: d.queuedStretch!,
                      onUndo: () => _undoPlanChange(context, ref, d),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                StaggeredEntrance(
                  index: index++,
                  child: const _SectionTitle('Payments'),
                ),
                const SizedBox(height: AppSpace.sm),
                if (d.payments.isEmpty)
                  StaggeredEntrance(
                    index: index++,
                    child: Text(
                      'Record his first payment.',
                      style: AppType.body.copyWith(color: palette.secondary),
                    ),
                  )
                else
                  for (final p in d.payments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: StaggeredEntrance(
                        index: index++,
                        child: _PaymentRow(
                          payment: p,
                          onTap: () => _openPay(context, d, existing: p),
                        ),
                      ),
                    ),
                const SizedBox(height: AppSpace.lg),
                StaggeredEntrance(
                  index: index++,
                  child: const _SectionTitle('History'),
                ),
                const SizedBox(height: AppSpace.sm),
                if (history.isEmpty)
                  StaggeredEntrance(
                    index: index++,
                    child: Text(
                      'No earlier subscriptions yet.',
                      style: AppType.body.copyWith(color: palette.secondary),
                    ),
                  )
                else
                  for (final s in history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: StaggeredEntrance(
                        index: index++,
                        child: _HistoryRow(sub: s),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
      bottomSheet: detail.maybeWhen(
        data: (d) => _ActionBar(
          detail: d,
          onPay: () => _openPay(context, d),
          onCall: () => ContactLauncher.call(context, d.member.phone),
          onWhatsApp: () =>
              ContactLauncher.openWhatsApp(context, d.member.phone),
          onChangePlan: () => _openChangePlan(context, d),
          onCancel: () => _openCancel(context, d),
          onReactivate: () => _openReactivate(context, d),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

/// The identifying header: ring + initials, name, phone, note, and the bucket
/// he sits in today.
class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final MemberDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tab = detail.tab;
    final note = detail.member.note ?? '';
    final entry = MemberWithDues(
      member: detail.member,
      tab: tab,
      inForce: detail.inForce,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemberAvatar(entry: entry, size: 66),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      detail.member.name,
                      style: AppType.title.copyWith(color: palette.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (detail.cancelled) ...[
                    const SizedBox(width: AppSpace.sm),
                    const MemberCancelledBadge(),
                  ],
                ],
              ),
              Text(
                detail.member.phone,
                style: AppType.body.copyWith(color: palette.secondary),
              ),
              if (note.isNotEmpty)
                Text(
                  note,
                  style: AppType.caption.copyWith(color: palette.secondary),
                ),
              const SizedBox(height: AppSpace.xs),
              Text(
                tab.bucket.label,
                style: AppType.caption.copyWith(
                  color: dueTextColor(palette, tab.bucket),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `₹2,267 pending · due 12 Oct` — what he owes and when it is asked for, then
/// what he has paid against it, and where his clock stopped once he has.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.tab});

  final MemberTab tab;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppType.caption.copyWith(color: palette.secondary);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            moneyLine(tab),
            style: AppType.body.copyWith(
              color: dueTextColor(palette, tab.bucket),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (tab.paid > 0) ...[
            const SizedBox(height: AppSpace.xs),
            Text('${rupees(tab.paid)} received so far', style: caption),
          ],
          if (tab.payableTo != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text('Payable to ${shortDate(tab.payableTo!)}', style: caption),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppType.subtitle.copyWith(color: context.palette.text),
    );
  }
}

/// The stretch running today: the plan it was sold on, its price and length,
/// the cycle it is inside, and the start-date correction.
class _InForceCard extends StatelessWidget {
  const _InForceCard({
    required this.sub,
    required this.tab,
    required this.onAdjustStart,
  });

  final Subscription sub;
  final MemberTab tab;
  final VoidCallback onAdjustStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = dueTextColor(palette, tab.bucket);
    final caption = AppType.caption.copyWith(color: palette.secondary);
    final price = sub.price;
    final days = sub.durationDays;
    final term = days == null ? null : '$days ${days == 1 ? 'day' : 'days'}';
    final priceLabel = price == null ? null : rupees(price);
    final window = cycleWindow(sub, DateTime.now());
    final range = window == null
        ? 'Starts ${shortDate(sub.startDate)}'
        : '${shortDate(window.start)} → ${shortDate(window.end)}';
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: status),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Springs once when the bucket changes — i.e. when a payment or
              // the calendar moves him.
              AnimatedStatusDot(color: status, statusKey: tab.bucket),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.planName ?? 'Add a plan',
                      style: AppType.body.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(range, style: caption),
                    Text(
                      [?priceLabel, ?term].join(' · '),
                      style: caption,
                    ),
                  ],
                ),
              ),
              Text(
                tab.bucket.label,
                style: AppType.caption.copyWith(
                  color: status,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TapScale(
              // The sheet fires Haptics.sheet() when it arrives.
              enableHaptic: false,
              child: TextButton.icon(
                onPressed: onAdjustStart,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  foregroundColor: palette.accentText,
                ),
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('Adjust start date'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Cancelled on 20 Jul` — his clock stopped; nothing accrues until a new
/// subscription starts from today.
class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.payableTo});

  final DateTime? payableTo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final day = payableTo;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day == null ? 'Cancelled' : 'Cancelled on ${shortDate(day)}',
            style: AppType.body.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Reactivate when he comes back.',
            style: AppType.caption.copyWith(color: palette.secondary),
          ),
        ],
      ),
    );
  }
}

class _NoSubscriptionCard extends StatelessWidget {
  const _NoSubscriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        'Reactivate to start a subscription.',
        style: AppType.body.copyWith(color: context.palette.secondary),
      ),
    );
  }
}

/// The change already written for a future day: `Switches to 3 months · ₹3,333
/// on 12 Oct`, reversible with Undo until that day arrives.
class _QueuedCard extends StatelessWidget {
  const _QueuedCard({required this.queued, required this.onUndo});

  final Subscription queued;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final price = queued.price;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Switches to ${queued.planName ?? 'a new plan'}'
            '${price == null ? '' : ' · ${rupees(price)}'}'
            ' on ${shortDate(queued.startDate)}',
            style: AppType.body.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Nothing changes until then.',
            style: AppType.caption.copyWith(color: palette.secondary),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TapScale(
              // Undo commits on its own success haptic.
              enableHaptic: false,
              child: TextButton(
                onPressed: onUndo,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  foregroundColor: palette.accentText,
                ),
                child: const Text('Undo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One receipt: the amount, the day, the note. Tapping corrects or deletes it.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});

  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final note = payment.note ?? '';
    return PressableRow(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rupees(payment.amount),
                    style: AppType.body.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (note.isNotEmpty)
                    Text(
                      note,
                      style: AppType.caption.copyWith(color: palette.secondary),
                    ),
                ],
              ),
            ),
            Text(
              shortDate(payment.paidOn),
              style: AppType.caption.copyWith(color: palette.secondary),
            ),
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.chevron_right, size: 18, color: palette.secondary),
          ],
        ),
      ),
    );
  }
}

/// One ended stretch: `12 May → 20 Jul · Cancelled`.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.sub});

  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppType.caption.copyWith(color: palette.secondary);
    final end = sub.endedOn;
    final reason = sub.endReason?.label;
    final price = sub.price;
    final days = sub.durationDays;
    final term = days == null ? null : '$days ${days == 1 ? 'day' : 'days'}';
    final priceLabel = price == null ? null : rupees(price);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub.planName ?? 'Subscription',
            style: AppType.body.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            [
              end == null
                  ? shortDate(sub.startDate)
                  : '${shortDate(sub.startDate)} → ${shortDate(end)}',
              ?reason,
            ].join(' · '),
            style: caption,
          ),
          Text(
            [?priceLabel, ?term].join(' · '),
            style: caption,
          ),
        ],
      ),
    );
  }
}

/// The thumb-zone actions: Pay (the shared payment sheet) / Call / WhatsApp,
/// then Change plan and Cancel — or Reactivate once he has stopped.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.detail,
    required this.onPay,
    required this.onCall,
    required this.onWhatsApp,
    required this.onChangePlan,
    required this.onCancel,
    required this.onReactivate,
  });

  final MemberDetail detail;
  final VoidCallback onPay;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onChangePlan;
  final VoidCallback onCancel;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final inForce = detail.inForce;
    // A queued plan change already holds the next switch: Change plan hides
    // until it is undone, and Undo sits on the queued line itself.
    final canChangePlan =
        inForce != null && detail.queuedStretch == null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          AppSpace.sm,
          AppSpace.screen,
          AppSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TapScale(
                      // The pay sheet haptics when it arrives.
                      enableHaptic: false,
                      child: FilledButton(
                        onPressed: onPay,
                        child: const Text('Pay'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                _IconAction(
                  icon: Icons.call,
                  tooltip: 'Call',
                  onTap: onCall,
                ),
                const SizedBox(width: AppSpace.sm),
                _IconAction(
                  icon: Icons.chat,
                  tooltip: 'WhatsApp',
                  onTap: onWhatsApp,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            if (inForce == null)
              SizedBox(
                height: 48,
                child: TapScale(
                  enableHaptic: false,
                  child: OutlinedButton(
                    onPressed: onReactivate,
                    child: const Text('Reactivate'),
                  ),
                ),
              )
            else
              Row(
                children: [
                  if (canChangePlan)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TapScale(
                          enableHaptic: false,
                          child: OutlinedButton(
                            onPressed: onChangePlan,
                            child: const Text('Change plan'),
                          ),
                        ),
                      ),
                    ),
                  if (canChangePlan) const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TapScale(
                        enableHaptic: false,
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.error,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: TapScale(
        // The launcher fires the tap haptic itself.
        enableHaptic: false,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Icon(icon, semanticLabel: tooltip),
        ),
      ),
    );
  }
}
