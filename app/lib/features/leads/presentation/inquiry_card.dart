/// One inquiry row: name + status badge, phone and age, the note, and
/// icon-only Call/WhatsApp quick actions.
///
/// The card is a doorway, not an action: a tap opens [showLeadActionsSheet],
/// where the status moves (`Mark contacted`, `Convert to member`, `Mark lost`)
/// sit next to Call/WhatsApp, so a tap can no longer be mistaken for one of
/// them. The two quick actions stay on the row for the one-tap case.
///
/// Motion: the surface is a [PressableCard] (press response only — the sheet
/// fires the arrival haptic), the status badge transitions in place instead of
/// swapping, and the converged (joined) state draws an [AnimatedCheck].
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/contact/contact_launcher.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/inquiry.dart';
import 'lead_actions_sheet.dart';

/// `12 Mar` — the absolute fallback once a lead is no longer recent.
final _dayMonth = DateFormat('d MMM');

/// Past this many days the added line names the date instead of counting days
/// (`docs/voice.md` rule 4) — the same window the dues lines use.
const int _relativeDays = 14;

/// `Added today` / `Added yesterday` / `Added 3 days ago` while the lead is
/// close, `Added 12 Mar` once it is not.
String _addedLine(DateTime createdAt, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  final added = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final days = day.difference(added).inDays;
  if (days <= 0) return 'Added today';
  if (days == 1) return 'Added yesterday';
  return days <= _relativeDays
      ? 'Added $days days ago'
      : 'Added ${_dayMonth.format(added)}';
}

class InquiryCard extends StatelessWidget {
  const InquiryCard({super.key, required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final note = inquiry.note;
    return PressableCard(
      // The tap opens the action sheet, whose arrival haptic is this gesture's
      // one haptic — so this surface only supplies the press response.
      onTap: () => showLeadActionsSheet(context, inquiry),
      enableHaptic: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(inquiry.name,
                    style:
                        AppType.subtitle.copyWith(color: context.palette.text)),
              ),
              const SizedBox(width: AppSpace.sm),
              _StatusBadge(status: inquiry.status),
              const SizedBox(width: AppSpace.xs),
              // Reads as tappable: the row is the way to every action.
              Icon(Icons.chevron_right,
                  size: 20, color: context.palette.secondary),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '${inquiry.phone} · '
            '${_addedLine(inquiry.createdAt, DateTime.now())}',
            style: AppType.caption.copyWith(color: context.palette.secondary),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(note,
                style: AppType.body.copyWith(color: context.palette.text),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              _IconAction(
                icon: Icons.call,
                label: 'Call ${inquiry.name}',
                onTap: () => ContactLauncher.call(context, inquiry.phone),
              ),
              const SizedBox(width: AppSpace.sm),
              _IconAction(
                icon: Icons.chat,
                label: 'Message on WhatsApp',
                onTap: () =>
                    ContactLauncher.openWhatsApp(context, inquiry.phone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status pill that transitions between statuses in place: the border/label
/// colour lerps over [MotionSpec.toggle] (175 ms) with one small scale pop, and
/// the leading tick draws in when the lead converges to `joined`.
class _StatusBadge extends StatefulWidget {
  const _StatusBadge({required this.status});
  final InquiryStatus status;

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Colour rendered on the previous frame — the "from" of a transition.
  Color? _from;
  Color? _last;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionSpec.toggle.duration,
      value: 1,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotionConfig.of(context).reduceMotion;
  }

  @override
  void didUpdateWidget(covariant _StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status == widget.status) return;
    _from = _last;
    _ctrl.value = 0;
    if (_reduceMotion) {
      _ctrl.value = 1;
    } else {
      MotionSpec.toggle.drive(_ctrl, target: 1);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static Color _colorFor(BuildContext context, InquiryStatus status) {
    switch (status) {
      case InquiryStatus.fresh:
        return context.palette.warning;
      case InquiryStatus.contacted:
        return context.palette.secondary;
      case InquiryStatus.joined:
        return context.palette.success;
      case InquiryStatus.lost:
        return context.palette.error;
    }
  }

  static String _labelFor(InquiryStatus status) {
    switch (status) {
      case InquiryStatus.fresh:
        return 'New';
      case InquiryStatus.contacted:
        return 'Contacted';
      case InquiryStatus.joined:
        return 'Joined';
      case InquiryStatus.lost:
        return 'Lost';
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _colorFor(context, widget.status);
    final from = _from;
    _last = target;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value.clamp(0.0, 1.0);
        final color = from == null ? target : Color.lerp(from, target, t)!;
        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The slot is always reserved, so converging to joined draws the
              // tick in without shifting the badge's width.
              AnimatedCheck(
                selected: widget.status == InquiryStatus.joined,
                color: color,
                size: 14,
                strokeWidth: 2,
              ),
              const SizedBox(width: 4),
              Text(_labelFor(widget.status),
                  style: AppType.caption.copyWith(color: color)),
            ],
          ),
        );
        if (_reduceMotion || from == null) return badge;
        return Transform.scale(scale: 0.92 + 0.08 * t, child: badge);
      },
    );
  }
}

/// Icon-only circular action for a list row: a 48 pt target, one screen-reader
/// label, a tooltip for pointer platforms, press feedback from [TapScale] and
/// the launch's haptic from [ContactLauncher].
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      // Press feedback; the launch itself fires the haptic.
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: SizedBox.square(
            dimension: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const CircleBorder(),
                foregroundColor: context.palette.accentText,
                side: BorderSide(color: context.palette.border),
              ),
              onPressed: onTap,
              child: Icon(icon, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
