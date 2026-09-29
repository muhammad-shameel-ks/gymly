/// Convert-to-member sheet: plan picker (optional first subscription).
///
/// Creates the member + optional first subscription, marks inquiry `joined`.
/// Duplicate phone → surfaces the existing member id so the caller can
/// open the existing member instead.
///
/// Motion: sheet timing from [AppTransitions.sheetController]; success fires one
/// decisive confirmation beat (≤500 ms, once) before the sheet hands back, so
/// the list row can settle into its joined state.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/leads_providers.dart';
import '../data/inquiries_repository.dart';
import '../data/inquiry.dart';

/// Shown after convert. [existingMemberId] is set when the phone already
/// belongs to a member in this gym.
typedef ConvertedCallback = void Function(
    {required String memberId, String? existingMemberId});

Future<void> showConvertSheet(BuildContext context, Inquiry inquiry,
    {ConvertedCallback? onConverted}) async {
  Haptics.sheet();
  final controller = AppTransitions.sheetController(
    Navigator.of(context),
    reduceMotion: AppMotionConfig.reduceMotionOf(context),
  );
  try {
    await showModalBottomSheet<void>(
      context: context,
      transitionAnimationController: controller,
      builder: (_) => _ConvertForm(inquiry: inquiry, onConverted: onConverted),
    );
  } finally {
    controller.dispose();
  }
}

class _ConvertForm extends ConsumerStatefulWidget {
  const _ConvertForm({required this.inquiry, this.onConverted});

  final Inquiry inquiry;
  final ConvertedCallback? onConverted;

  @override
  ConsumerState<_ConvertForm> createState() => _ConvertFormState();
}

class _ConvertFormState extends ConsumerState<_ConvertForm> {
  String? _planId; // null = member only, no first subscription.
  Timer? _closeTimer;
  bool _converted = false;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<void> _convert() async {
    // Captured before the await so the confirmation survives the sheet's pop.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final memberId =
          await ref.read(leadsControllerProvider.notifier).convert(
                widget.inquiry,
                planId: _planId,
              );
      if (!mounted || memberId == null) return;
      Haptics.success();
      // One decisive beat, then the row settles into `joined` under the sheet.
      setState(() => _converted = true);
      _closeTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        navigator.pop();
        widget.onConverted?.call(memberId: memberId);
        messenger.showSnackBar(
          SnackBar(content: Text('${widget.inquiry.name} is now a member.')),
        );
      });
    } on DuplicateMemberException catch (e) {
      if (!mounted) return;
      Haptics.error();
      navigator.pop();
      widget.onConverted
          ?.call(memberId: e.memberId, existingMemberId: e.memberId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              '${widget.inquiry.name} is already a member. Opened the existing record.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Haptics.error();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't convert this lead. Check your connection, then try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(convertPlansProvider);
    final converting = ref.watch(leadsControllerProvider).isLoading;
    return SafeArea(
      // The confirmation covers the form in place, so the sheet does not resize.
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: _converted,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen, AppSpace.md, AppSpace.screen, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Convert ${widget.inquiry.name}',
                      style: AppType.subtitle
                          .copyWith(color: context.palette.text)),
                  const SizedBox(height: 4),
                  Text(widget.inquiry.phone,
                      style: AppType.caption
                          .copyWith(color: context.palette.secondary)),
                  const SizedBox(height: AppSpace.md),
                  Text('First plan',
                      style: AppType.body
                          .copyWith(color: context.palette.text)),
                  const SizedBox(height: 4),
                  Text('Optional — you can add one later.',
                      style: AppType.caption
                          .copyWith(color: context.palette.secondary)),
                  const SizedBox(height: AppSpace.sm),
                  plans.when(
                    loading: () => const Shimmer(
                      child: Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          ShimmerBox(
                              width: 96,
                              height: 36,
                              radius: AppRadius.pill),
                          ShimmerBox(
                              width: 132,
                              height: 36,
                              radius: AppRadius.pill),
                        ],
                      ),
                    ),
                    error: (_, _) => Text(
                        "Couldn't load plans. Convert without one.",
                        style: AppType.caption
                            .copyWith(color: context.palette.secondary)),
                    data: (list) {
                      if (list.isEmpty) {
                        return Text('No plans yet. Convert without one.',
                            style: AppType.caption
                                .copyWith(color: context.palette.secondary));
                      }
                      return Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          TapScale(
                            child: ChoiceChip(
                              label: const Text('Member only'),
                              selected: _planId == null,
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                color: _planId == null
                                    ? context.palette.onAccent
                                    : context.palette.secondary,
                              ),
                              checkmarkColor: context.palette.onAccent,
                              selectedColor: context.palette.accent,
                              onSelected: (_) {
                                if (_planId == null) return;
                                Haptics.select();
                                setState(() => _planId = null);
                              },
                            ),
                          ),
                          for (final p in list)
                            TapScale(
                              child: ChoiceChip(
                                label: Text(
                                  '${p.name} · ${p.amountDaysLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                                selected: _planId == p.id,
                                selectedColor: context.palette.accent,
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                  color: _planId == p.id
                                      ? context.palette.onAccent
                                      : context.palette.secondary,
                                ),
                                checkmarkColor: context.palette.onAccent,
                                onSelected: (_) {
                                  if (_planId == p.id) return;
                                  Haptics.select();
                                  setState(() => _planId = p.id);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpace.md),
                  TapScale(
                    // Press feedback only; the convert carries success/error.
                    enabled: !converting,
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: converting ? null : _convert,
                        child: converting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Convert to member'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_converted)
            Positioned.fill(
              child: ColoredBox(
                color: context.palette.surface,
                child: Center(child: _ConvertedMoment(name: widget.inquiry.name)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one-beat confirmation: the tick draws in, then the sheet hands back.
class _ConvertedMoment extends StatefulWidget {
  const _ConvertedMoment({required this.name});

  final String name;

  @override
  State<_ConvertedMoment> createState() => _ConvertedMomentState();
}

class _ConvertedMomentState extends State<_ConvertedMoment> {
  bool _draw = false;

  @override
  void initState() {
    super.initState();
    // Flip after the first frame so the tick has a from-state to draw in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _draw = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RiseIn(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedCheck(
            selected: _draw,
            size: 44,
            strokeWidth: 3,
            color: context.palette.success,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '${widget.name} is now a member.',
            style: AppType.subtitle.copyWith(color: context.palette.text),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
