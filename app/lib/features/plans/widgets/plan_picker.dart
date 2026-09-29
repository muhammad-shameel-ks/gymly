/// Shared plan picker, reusable from the Members and Leads slices.
///
/// Watches [plansListProvider] for [gymId] and renders a dropdown of plans.
/// States: loading → the field's own silhouette as a [Shimmer] skeleton;
/// error → the field plus a `Retry` control; empty → the next action in the
/// owner's words; data → full dropdown with `name · ₹amount · duration`
/// labels.
///
/// Motion + haptics come from `core/motion`: the field carries the shared press
/// feedback ([TapScale] — no gesture takeover, so the dropdown keeps its own
/// tap) and moving the value to another plan fires [Haptics.select] (a discrete
/// value moved: the picker/chip meaning). The `Retry` control fires the press
/// impact. Loading never spins a spinner: it shimmers the shape the field will
/// take.
///
/// Colours come from [AppPalette] (`context.palette`), so the field, menu and
/// chip flip with the theme.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/plan.dart';
import '../providers/plans_providers.dart';

/// Dropdown picker for assigning a plan to a member/subscription.
///
/// [gymId] scopes the query. [selectedPlanId] is the current selection
/// (null = none). Set [allowNone] to offer a [noneLabel] entry.
class PlanPicker extends ConsumerWidget {
  const PlanPicker({
    super.key,
    required this.gymId,
    required this.selectedPlanId,
    required this.onChanged,
    this.label = 'Plan',
    this.allowNone = true,
    this.noneLabel = 'No plan yet',
  });

  final String gymId;
  final String? selectedPlanId;

  /// Fires with the chosen plan, or null when [noneLabel] is chosen.
  final ValueChanged<Plan?> onChanged;

  final String label;
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plans = ref.watch(plansListProvider(gymId));
    final textStyle = AppType.body.copyWith(color: palette.text);
    return plans.when(
      skipLoadingOnReload: true,
      // The skeleton mirrors the field's height and radius, so the form does
      // not jump when the plans land.
      loading: () => const Shimmer(
        child: ShimmerBox(height: 56, radius: AppRadius.card),
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Plan>(
            decoration: _decoration(hint: "Couldn't load plans"),
            items: const [],
            onChanged: null,
            initialValue: null,
          ),
          const SizedBox(height: AppSpace.sm),
          TapScale(
            child: TextButton.icon(
              onPressed: () {
                // Pressed: the state swaps back to the skeleton.
                Haptics.impact();
                ref.invalidate(plansListProvider(gymId));
              },
              style: TextButton.styleFrom(foregroundColor: palette.secondary),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return InputDecorator(
            decoration: _decoration(hint: null),
            child: Text(
              'Add a plan on the Plans tab, then choose it here.',
              style: AppType.body.copyWith(color: palette.secondary),
            ),
          );
        }
        final selected = selectedPlanId == null
            ? null
            : list.where((p) => p.id == selectedPlanId).firstOrNull;
        return TapScale(
          child: DropdownButtonFormField<Plan>(
            decoration: _decoration(hint: null),
            initialValue: selected,
            style: textStyle,
            dropdownColor: palette.surface,
            iconEnabledColor: palette.secondary,
            items: [
              if (allowNone)
                DropdownMenuItem<Plan>(
                  value: null,
                  child: Text(noneLabel, style: textStyle),
                ),
              for (final plan in list)
                DropdownMenuItem<Plan>(
                  value: plan,
                  child: Text(
                    plan.label,
                    style: textStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (plan) {
              // A discrete value moved — `No plan yet` included; the picker's
              // one haptic, fired before the caller's own state change.
              Haptics.select();
              onChanged(plan);
            },
          ),
        );
      },
    );
  }

  InputDecoration _decoration({String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
      );
}

/// Read-only duration chip, e.g. `3 months`.
///
/// The informative signature of a plan in a row: name · amount · **duration**,
/// kept compact and unanimated. It is not interactive, so it takes no press
/// state and no haptic (`core/motion/PROTOCOL.md`: never haptic a data change).
class PlanDurationChip extends StatelessWidget {
  const PlanDurationChip({super.key, required this.durationDays});

  final int durationDays;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        durationLabel(durationDays),
        style: AppType.caption.copyWith(color: palette.text),
      ),
    );
  }
}
