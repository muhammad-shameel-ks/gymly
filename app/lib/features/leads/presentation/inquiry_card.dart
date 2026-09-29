/// One inquiry row: name/phone/note + status badge, icon-only Call/WhatsApp,
/// and one labelled advance action.
///
/// Advance: new -> "Mark contacted"; contacted -> "Convert to member";
/// lost/joined show a static badge plus "Mark lost" for open inquiries.
///
/// Motion: the surface is a [PressableCard] (press response + the row's one
/// haptic), the status badge transitions in place instead of swapping, and the
/// converged (joined) state draws an [AnimatedCheck].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/leads_providers.dart';
import '../data/inquiry.dart';

class InquiryCard extends ConsumerWidget {
  const InquiryCard({super.key, required this.inquiry, required this.onConvert});

  final Inquiry inquiry;
  final VoidCallback onConvert;

  bool get _open =>
      inquiry.status == InquiryStatus.fresh ||
      inquiry.status == InquiryStatus.contacted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = _open;
    return PressableCard(
      // An open lead's row press is its primary move (the same action the
      // button offers); the haptic is fired by the action itself, so this
      // surface only supplies the press response.
      onTap: open ? () => _advance(context, ref) : null,
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
              _StatusBadge(status: inquiry.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(inquiry.phone,
              style: AppType.caption
                  .copyWith(color: context.palette.secondary)),
          if (inquiry.note != null && inquiry.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(inquiry.note!,
                style: AppType.body.copyWith(color: context.palette.text),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              _IconAction(
                icon: Icons.call,
                label: 'Call ${inquiry.phone}',
                onTap: () => _call(inquiry.phone),
              ),
              const SizedBox(width: AppSpace.sm),
              _IconAction(
                icon: Icons.chat,
                label: 'Message on WhatsApp',
                onTap: () => _whatsapp(inquiry.phone),
              ),
              // The one labelled action takes whatever is left and ellipsizes;
              // no fixed Spacer, so nothing can push the row past the card edge.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: open
                      ? TapScale(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _advance(context, ref),
                            child: Text(
                              inquiry.status.advanceLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          if (open)
            Align(
              alignment: Alignment.centerRight,
              child: TapScale(
                child: TextButton(
                  onPressed: () => _markLost(context, ref),
                  child: Text('Mark lost',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(color: context.palette.secondary)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    if (inquiry.status == InquiryStatus.contacted) {
      // The convert sheet fires its own arrival haptic.
      onConvert();
      return;
    }
    Haptics.select();
    final ok = await ref
        .read(leadsControllerProvider.notifier)
        .setStatus(inquiry, InquiryStatus.contacted);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't mark this contacted. Check your connection, then try again."),
        ),
      );
    }
  }

  Future<void> _markLost(BuildContext context, WidgetRef ref) async {
    Haptics.select();
    final ok = await ref
        .read(leadsControllerProvider.notifier)
        .setStatus(inquiry, InquiryStatus.lost);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't mark this lost. Check your connection, then try again."),
        ),
      );
    }
  }

  Future<void> _call(String phone) async {
    Haptics.impact();
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    Haptics.impact();
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

/// Icon-only circular action for a list row: a 44 pt target, one screen-reader
/// label, a tooltip for pointer platforms, press feedback from [TapScale] and
/// the launch's haptic from the action itself.
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
            dimension: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
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
