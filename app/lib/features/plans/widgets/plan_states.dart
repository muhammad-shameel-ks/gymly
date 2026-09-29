/// Shared list states: skeleton + guided-empty + error-retry.
///
/// Every list in this slice renders one of these per DESIGN.md §4: loading
/// (a [Shimmer] skeleton that mirrors the eventual row) + empty (the next action
/// in the owner's words) + error (what happened → what to do → `Retry`). Each
/// state rises in once via [RiseIn], and the skeleton's sweep is the app's only
/// loop — it is scoped to the placeholders and disappears with them. Tap targets
/// ≥ 48dp; colours come from [AppPalette] so they flip with the theme.
library;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/scrollable_state_body.dart';

/// Skeleton rows mirroring the plan-row layout (name + amount + chip).
class PlanListSkeleton extends StatelessWidget {
  const PlanListSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    // One sweep over the whole skeleton list: a single controller, a single
    // gradient, and nothing left running once the real rows mount.
    return Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.screen,
          vertical: AppSpace.md,
        ),
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.gap),
        itemBuilder: (_, _) => const _SkeletonRow(),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Row(
        children: [
          ShimmerBox(width: 120, height: 18, radius: 9),
          Spacer(),
          ShimmerBox(width: 64, height: 16, radius: 8),
          SizedBox(width: AppSpace.gap),
          ShimmerBox(width: 72, height: 28, radius: 14),
        ],
      ),
    );
  }
}

/// Guided empty state with a next action.
class PlanEmpty extends StatelessWidget {
  const PlanEmpty({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ScrollableStateBody(
      child: RiseIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_membership, size: 48, color: palette.secondary),
            const SizedBox(height: AppSpace.md),
            Text(
              'Add your first plan',
              style: AppType.subtitle.copyWith(color: palette.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Set the price and duration once, then assign it to members '
              'when they join.',
              style: AppType.body.copyWith(color: palette.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 48,
              child: TapScale(
                child: FilledButton(
                  onPressed: () {
                    // Pressed: the sheet arriving is the visible change.
                    Haptics.impact();
                    onCreate();
                  },
                  style: FilledButton.styleFrom(
                    textStyle:
                        AppType.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Add plan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state: what happened → what to do → retry.
class PlanError extends StatelessWidget {
  const PlanError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// What to do next, in the owner's words (`Check your connection, then try
  /// again.`). Never the raw exception — `docs/voice.md` forbids printing it,
  /// so the caller passes voice copy instead of `'$err'`.
  final String message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ScrollableStateBody(
      child: RiseIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: palette.error),
            const SizedBox(height: AppSpace.md),
            Text(
              "Couldn't load plans",
              style: AppType.subtitle.copyWith(color: palette.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              message,
              style: AppType.body.copyWith(color: palette.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 48,
              child: TapScale(
                child: OutlinedButton(
                  onPressed: () {
                    // Pressed: the state swaps back to the skeleton.
                    Haptics.impact();
                    onRetry();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.text,
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompt shown when no single gym is selected (other tabs filter to one
/// gym; Home alone aggregates "All gyms").
class PlanPickGymPrompt extends StatelessWidget {
  const PlanPickGymPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ScrollableStateBody(
      child: RiseIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store, size: 48, color: palette.secondary),
            const SizedBox(height: AppSpace.md),
            Text(
              'Pick a gym to see its plans',
              style: AppType.subtitle.copyWith(color: palette.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Choose a gym in the header above.',
              style: AppType.body.copyWith(color: palette.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
