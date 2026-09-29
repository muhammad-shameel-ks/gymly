/// Lead action sheet: every move for one inquiry, in one place.
///
/// A lead card is a doorway, not an action, so a card tap lands here instead of
/// guessing whether the owner meant "call" or "convert". Rows, in order:
///
/// - `Call {name}` / `Message on WhatsApp` — always, routed through
///   [ContactLauncher] (it normalises the number, fires the impact haptic and
///   reports failure itself).
/// - `Mark contacted` — a new lead.
/// - `Convert to member` — a contacted lead; opens the existing convert sheet.
/// - `Mark lost` — any open (new/contacted) lead, in the destructive colour and
///   set apart from the rest.
///
/// Joined/lost leads keep Call/WhatsApp only; their badge is the record.
///
/// Haptics: one per tap — [Haptics.sheet] for the arrival, then the action
/// owner's own (the launcher's impact, the status write's select, the convert
/// sheet's arrival), so no row adds a second.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contact/contact_launcher.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../application/leads_providers.dart';
import '../data/inquiry.dart';
import 'convert_sheet.dart';

/// Opens the actions available on [inquiry].
Future<void> showLeadActionsSheet(BuildContext context, Inquiry inquiry) async {
  // The arrival haptic; the card suppresses its own press haptic for this tap.
  Haptics.sheet();
  await showAppSheet<void>(
    context,
    builder: (_) => AppSheet(
      title: inquiry.name,
      child: _LeadActions(inquiry: inquiry, host: context),
    ),
  );
}

/// The sheet's rows. [host] is the surface that opened the sheet (a lead card):
/// it outlives the sheet, so an action that closes the sheet first still has a
/// live context to launch from and to report failure through.
class _LeadActions extends ConsumerWidget {
  const _LeadActions({required this.inquiry, required this.host});

  final Inquiry inquiry;
  final BuildContext host;

  bool get _open =>
      inquiry.status == InquiryStatus.fresh ||
      inquiry.status == InquiryStatus.contacted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionRow(
          icon: Icons.call,
          label: 'Call ${inquiry.name}',
          onPressed: () => _closeThen(context, () {
            ContactLauncher.call(host, inquiry.phone);
          }),
        ),
        const SizedBox(height: AppSpace.sm),
        _ActionRow(
          icon: Icons.chat,
          label: 'Message on WhatsApp',
          onPressed: () => _closeThen(context, () {
            ContactLauncher.openWhatsApp(host, inquiry.phone);
          }),
        ),
        if (inquiry.status == InquiryStatus.fresh) ...[
          const SizedBox(height: AppSpace.sm),
          _ActionRow(
            icon: Icons.check,
            label: 'Mark contacted',
            onPressed: () => _setStatus(context, ref, InquiryStatus.contacted),
          ),
        ],
        if (inquiry.status == InquiryStatus.contacted) ...[
          const SizedBox(height: AppSpace.sm),
          _ActionRow(
            icon: Icons.person_add_alt,
            label: 'Convert to member',
            // The convert sheet fires its own arrival haptic.
            onPressed: () => _closeThen(context, () {
              showConvertSheet(host, inquiry);
            }),
          ),
        ],
        if (_open) ...[
          // Wider than the row gap, so the destructive row cannot be hit by
          // accident on the way to a neutral one.
          const SizedBox(height: AppSpace.md),
          _ActionRow(
            icon: Icons.block,
            label: 'Mark lost',
            destructive: true,
            onPressed: () => _setStatus(context, ref, InquiryStatus.lost),
          ),
        ],
      ],
    );
  }

  /// Closes the sheet, then runs [action] — the sheet never stays up behind a
  /// dialer or a second sheet.
  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  /// The status write behind `Mark contacted` / `Mark lost`: one select haptic,
  /// the sheet closes, then the write runs and reports its own failure.
  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    InquiryStatus status,
  ) async {
    Haptics.select();
    // Captured before the pop: the notifier is container-owned and the
    // messenger outlives the sheet, so neither is used after its element dies.
    final controller = ref.read(leadsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final ok = await controller.setStatus(inquiry, status);
    if (ok) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          status == InquiryStatus.contacted
              ? "Couldn't mark this contacted. Check your connection, then try again."
              : "Couldn't mark this lost. Check your connection, then try again.",
        ),
      ),
    );
  }
}

/// One full-width 48 dp sheet row: icon + verb, then a trailing chevron.
///
/// [destructive] paints it in [AppPalette.error]; everything else uses the
/// primary text colour. The press response is [TapScale]'s — the haptic belongs
/// to the action behind the row.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground =
        destructive ? context.palette.error : context.palette.text;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TapScale(
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: foreground,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Icon(Icons.chevron_right,
                  size: 20, color: context.palette.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
