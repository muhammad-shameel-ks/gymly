/// The shared plan picker for the members slice's sheets: reactivate, change
/// plan, and the create form's first stretch.
///
/// One control, states included: a [Shimmer] field silhouette while the gym's
/// plans load, `Couldn't load plans.` plus `Retry` on failure, the Plans tab's
/// own wording when the gym has none (`Add a plan on the Plans tab, then choose
/// it here.`), and otherwise a dropdown of
/// `name · ₹amount · duration` ([PlanOption.label]). Nothing picked yet reads
/// `Choose a plan.`
///
/// Motions and haptics come from `core/motion`: moving the value fires
/// [Haptics.select]; the picker takes no arrival haptic of its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../providers/members_providers.dart';

/// Dropdown of the gym's plans. A plan is always required, so the only callback
/// reports a real choice — a sheet that allows "no plan" keeps its own control.
class GymPlanPicker extends ConsumerWidget {
  const GymPlanPicker({
    super.key,
    required this.gymId,
    required this.selectedId,
    required this.onSelected,
    this.label = 'Plan',
  });

  final String gymId;

  /// The plan currently chosen; null until the owner picks one.
  final String? selectedId;

  final ValueChanged<PlanOption> onSelected;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final textStyle = AppType.body.copyWith(color: palette.text);
    final plans = ref.watch(plansForGymProvider(gymId));
    return plans.when(
      skipLoadingOnReload: true,
      // The skeleton mirrors the field's height, so the form cannot jump.
      loading: () => const Shimmer(
        child: ShimmerBox(height: 56, radius: AppRadius.card),
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: label,
              hintText: "Couldn't load plans",
            ),
            items: const [],
            onChanged: null,
          ),
          const SizedBox(height: AppSpace.xs),
          TapScale(
            child: TextButton.icon(
              onPressed: () {
                // Pressed: the state swaps back to the skeleton.
                Haptics.impact();
                ref.invalidate(plansForGymProvider(gymId));
              },
              style: TextButton.styleFrom(foregroundColor: palette.accentText),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: label),
            items: const [],
            onChanged: null,
            hint: Text(
              'Add a plan on the Plans tab, then choose it here.',
              style: AppType.body.copyWith(color: palette.secondary),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: list.any((p) => p.id == selectedId) ? selectedId : null,
          decoration: InputDecoration(labelText: label, hintText: 'Choose a plan.'),
          style: textStyle,
          dropdownColor: palette.surface,
          iconEnabledColor: palette.secondary,
          isExpanded: true,
          items: [
            for (final plan in list)
              DropdownMenuItem<String>(
                value: plan.id,
                child: Text(
                  plan.label,
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id == null) return;
            // A discrete value moved: the picker's one haptic.
            Haptics.select();
            onSelected(list.firstWhere((p) => p.id == id));
          },
        );
      },
    );
  }
}
