/// Home dues card: name, plan, money line + thumb-zone actions.
///
/// One card per dues entry: the member's initials sit inside the signature
/// [DueRing] — filled with money paid against the plan he is on — then the name and
/// one caption: the gym (All-gyms feed only), the plan, and the money line
/// `₹2,000 pending · due 12 Oct` (`₹500 advance` when paid ahead) in the
/// bucket's status colour, the same colour the ring sweeps. Below it a
/// one-thumb action row: **Pay** (accent primary, opens the shared payment
/// sheet) / **Call** (`tel:`) / **WhatsApp** (`wa.me`). Cancel, Reactivate and
/// Change plan live on the member's record, never here. Tap targets ≥ 48dp,
/// 8px gaps.
///
/// Entrance, press and count-up motion all come from `core/motion`; there is no
/// local controller or timer here. Colours come from [AppPalette].
library;

import 'package:flutter/material.dart';

import '../../../core/contact/contact_launcher.dart';
import '../../../core/motion/motion.dart';
import '../../../core/signature/signature.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../members/widgets/due_cue.dart';
import '../../members/widgets/pay_sheet.dart';
import '../data/dues_providers.dart';

/// Dues card with Pay / Call / WhatsApp actions.
///
/// The card never writes: Pay hands off to [showPaySheet], which records the
/// receipt and refreshes the feed, so the card needs no provider of its own.
class DuesCard extends StatelessWidget {
  const DuesCard({super.key, required this.entry, this.index = 0, this.onTap});

  final DuesEntry entry;

  /// Position in the feed; drives the stagger delay (~40ms per card).
  final int index;

  /// Opens the member's record. Null leaves the card inert (no press state).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final palette = context.palette;
    // One status colour per bucket — the exact one `DueRing` sweeps — so the
    // money line and the ring read the same way (DESIGN.md §4).
    final status = dueTextColor(palette, e.bucket);
    // One caption, two ideas at most: the gym (All-gyms feed only) and the
    // plan stay secondary; the money line — what he owes and the date it
    // answers to — carries the bucket colour and its own wording, so the stage
    // never depends on colour alone.
    final money = moneyLine(e.tab);
    final caption = <InlineSpan>[
      if (e.gymName != null) TextSpan(text: '${e.gymName!} · '),
      TextSpan(text: e.planName ?? 'Add a plan'),
      if (money.isNotEmpty) ...[
        const TextSpan(text: ' · '),
        TextSpan(
          text: money,
          style: TextStyle(color: status, fontWeight: FontWeight.w600),
        ),
      ],
    ];

    return StaggeredEntrance(
      index: index,
      child: PressableCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DueRing(
                  // Nothing owed yet (a legacy row, or a stretch that has not
                  // started) paints the full muted ring instead of claiming a
                  // paid-up bucket; otherwise the ring is money paid against
                  // the plan he is on.
                  progress: e.tab.owed == 0 ? null : e.tab.ringFill,
                  bucket: e.bucket,
                  size: 42,
                  child: _MemberInitials(name: e.member.name),
                ),
                const SizedBox(width: AppSpace.sm + AppSpace.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.member.name,
                        style: AppType.body.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text.rich(
                        TextSpan(children: caption),
                        style: AppType.caption
                            .copyWith(color: palette.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm + AppSpace.xs),
            Row(
              children: [
                Expanded(
                  child: TapScale(
                    // The button owns the tap (semantics, keyboard); TapScale
                    // adds the press scale, the sheet arrival owns the haptic.
                    onTap: null,
                    dimOpacity: 0.94,
                    child: FilledButton(
                      onPressed: () => _openPay(context, e),
                      child: const Text(
                        'Pay',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                _DuesIconAction(
                  icon: Icons.call,
                  label: 'Call',
                  onTap: () => ContactLauncher.call(context, e.member.phone),
                ),
                const SizedBox(width: AppSpace.sm),
                _DuesIconAction(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: () =>
                      ContactLauncher.openWhatsApp(context, e.member.phone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPay(BuildContext context, DuesEntry e) {
    // One press, one haptic: a modal surface is arriving. The sheet pre-fills
    // what the member owes *now* (the instalments he is behind on), saves the
    // receipt, confirms it and refreshes every view that shows this member's
    // money — this feed included — so nothing happens here on the way back.
    Haptics.sheet();
    showPaySheet(
      context,
      gymId: e.member.gymId,
      memberId: e.member.id,
      pending: e.pending,
      dueNow: e.tab.dueNow,
    );
  }
}

/// Member initials centred in the ring: the ring says how much of the tab is
/// paid, the initials say who.
class _MemberInitials extends StatelessWidget {
  const _MemberInitials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.bg, shape: BoxShape.circle),
      child: Text(
        initials,
        style: AppType.caption.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DuesIconAction extends StatelessWidget {
  const _DuesIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 48,
      child: TapScale(
        onTap: null,
        dimOpacity: 0.94,
        child: OutlinedButton.icon(
          // Local: neutral (not accent) label, and a narrow padding so three
          // actions fit one row. Border/pill shape come from AppTheme.
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.text,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      ),
    );
  }
}
