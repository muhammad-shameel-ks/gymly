/// Plans tab: name + ₹ amount + duration chip, per gym.
///
/// Requires a single [gymId]; a null gym shows [PlanPickGymPrompt] (other
/// tabs filter to one gym — only Home aggregates "All gyms").
/// Create/edit via [PlanFormSheet]; archive is guarded by
/// [ReferencedPlanException] (see the form sheet's warning surface).
///
/// Motion (one entrance per visit, from `core/motion`): rows stagger in via
/// [StaggeredEntrance] keyed by plan id — so a re-ordered or edited row keeps
/// its element and never replays — the amount rolls in place with
/// [AnimatedAmount] when the owner edits a price, and every press (row, FAB,
/// empty-state CTA) carries the layer's press feedback plus one haptic. The
/// duration chip stays what it is: the compact informative label of the plan.
///
/// Colours come from [AppPalette] (`context.palette`) so dark/light match the
/// rest of the app; the create FAB takes the theme's accent fill + onAccent
/// icon.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/plan.dart';
import '../providers/plans_providers.dart';
import 'plan_form_sheet.dart';
import 'plan_picker.dart';
import 'plan_states.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key, required this.gymId});

  /// Null = "All gyms" selected → prompt to pick one gym.
  final String? gymId;

  /// Opens the create/edit sheet. The haptic for this gesture is fired by the
  /// control that was pressed (row, FAB or CTA) — one haptic per gesture
  /// (`core/motion/PROTOCOL.md`), so the sheet itself arrives silently and the
  /// theme supplies its surface colour and `AppRadius.sheet` top radius.
  void _openSheet(BuildContext context, Widget child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => child,
    );
  }

  void _openCreate(BuildContext context, String gymId) {
    _openSheet(context, PlanFormSheet(gymId: gymId));
  }

  void _openEdit(BuildContext context, String gymId, Plan plan) {
    _openSheet(context, PlanFormSheet(gymId: gymId, existing: plan));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymId = this.gymId;
    if (gymId == null) return const PlanPickGymPrompt();

    final palette = context.palette;
    final plans = ref.watch(plansListProvider(gymId));
    return Scaffold(
      backgroundColor: palette.bg,
      floatingActionButton: TapScale(
        child: FloatingActionButton(
          onPressed: () {
            // Pressed: the sheet arriving is the visible change.
            Haptics.impact();
            _openCreate(context, gymId);
          },
          tooltip: 'Add plan',
          child: const Icon(Icons.add),
        ),
      ),
      body: plans.when(
        skipLoadingOnReload: true,
        loading: () => const PlanListSkeleton(),
        error: (_, _) => PlanError(
          message: 'Check your connection, then try again.',
          onRetry: () => ref.invalidate(plansListProvider(gymId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return PlanEmpty(
              onCreate: () => _openCreate(context, gymId),
            );
          }
          return ListView.separated(
            // Bottom slack clears the FAB.
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screen,
              AppSpace.md,
              AppSpace.screen,
              88,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.gap),
            itemBuilder: (context, i) {
              final plan = list[i];
              // Keyed by plan: an edit that moves the row (the list is sorted
              // by amount) carries the row's state along instead of re-playing
              // the entrance, and the amount rolls where it already is.
              return StaggeredEntrance(
                key: ValueKey(plan.id),
                index: i,
                child: _PlanRow(
                  plan: plan,
                  onTap: () => _openEdit(context, gymId, plan),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.onTap});

  final Plan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = plan.amount.toDouble();
    // PressableCard = the row's press response (0.985 spring + 6% overlay) and
    // its own light impact haptic; the row is the one action, so the card owns
    // the gesture.
    return PressableCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: AppType.subtitle.copyWith(color: palette.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpace.xs),
                // Amounts settle in place when a price is edited. First paint
                // starts from the real value, so the entrance stays the only
                // thing that moves on arrival.
                AnimatedAmount(
                  amount: amount,
                  initialAmount: amount,
                  formatter: formatPlanAmount,
                  style: AppType.body.copyWith(color: palette.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.gap),
          PlanDurationChip(durationDays: plan.durationDays),
        ],
      ),
    );
  }
}
