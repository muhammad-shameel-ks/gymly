/// Home dues card: name, plan, due line, amount + thumb-zone actions.
///
/// One card per dues entry: the member's initials sit inside the signature
/// [DueRing] (how much of the period has run out — empty the day they renew,
/// full on the expiry date), then name + `gym · plan · due` line + amount, then
/// a one-thumb action row: **Renew** (accent primary, opens the Renew sheet) /
/// **Call** (`tel:`) / **WhatsApp** (`wa.me`). Tap targets ≥ 48dp, 8px gaps.
///
/// The ring's sweep is the bucket colour, so the card needs no separate status
/// dot. Entrance, press and count-up motion all come from `core/motion`;
/// there is no local controller or timer here. Colours come from [AppPalette].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contact/contact_launcher.dart';
import '../../../core/motion/motion.dart';
import '../../../core/signature/signature.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../members/widgets/due_cue.dart';
import '../../members/widgets/renew_sheet.dart';
import '../data/dues_providers.dart';

/// Dues card with Renew / Call / WhatsApp actions.
class DuesCard extends ConsumerWidget {
  const DuesCard({super.key, required this.entry, this.index = 0, this.onTap});

  final DuesEntry entry;

  /// Position in the feed; drives the stagger delay (~40ms per card).
  final int index;

  /// Opens the member's record. Null leaves the card inert (no press state).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = entry;
    final palette = context.palette;
    final current = e.current;
    final amount = current?.planAmount;
    // One status colour per bucket — the exact one `DueRing` sweeps — so the
    // due line and the ring read the same way (DESIGN.md §4).
    final status = dueTextColor(palette, e.bucket);
    // One caption, one idea: the gym (All-gyms feed only), the plan, the date.
    // Gym/plan stay secondary; the due line carries the bucket colour and its
    // own wording, so the stage never depends on colour alone.
    final caption = <InlineSpan>[
      if (e.gymName != null) TextSpan(text: '${e.gymName!} · '),
      if (current != null)
        TextSpan(text: '${current.planName ?? 'Add a plan'} · '),
      TextSpan(
        text: e.dueLine(),
        style: TextStyle(color: status, fontWeight: FontWeight.w600),
      ),
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
                  progress: periodProgress(current),
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
                const SizedBox(width: AppSpace.sm),
                if (amount == null)
                  Text(
                    // The model's own label for a member with no plan.
                    e.amountLabel,
                    style: AppType.body.copyWith(
                      color: palette.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  // Rolls only when the value on screen changes — never on
                  // first paint, so a card cannot show another member's amount.
                  AnimatedAmount(
                    amount: amount.toDouble(),
                    initialAmount: amount.toDouble(),
                    formatter: (v) =>
                        rupeeLabel(v, whole: amount.remainder(1) == 0),
                    style: AppType.body.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w700,
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
                      onPressed: () => _openRenew(context, ref, e),
                      child: const Text(
                        'Renew',
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

  void _openRenew(BuildContext context, WidgetRef ref, DuesEntry e) {
    // One press, one haptic: a modal surface is arriving.
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => RenewSheet(
        gymId: e.member.gymId,
        memberId: e.member.id,
        current: e.current,
      ),
    ).then((_) => invalidateDuesViews(ref));
  }
}

/// Member initials centred in the ring: the ring says how far through the
/// period the member is, the initials say who.
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
