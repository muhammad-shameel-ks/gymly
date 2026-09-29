/// Shared list states: skeleton + guided-empty + error-retry.
///
/// Every list in this slice renders one of these per DESIGN.md §4:
/// loading (a [Shimmer] skeleton mirroring the row layout) + empty (the next
/// action in the owner's words, then the control that does it) + error (what
/// happened → what to do → the control that does it). Tap targets ≥ 48dp.
library;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/scrollable_state_body.dart';

/// Skeleton rows mirroring the member-row layout (ring avatar + two lines).
class MemberListSkeleton extends StatelessWidget {
  const MemberListSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => const _SkeletonRow(),
    );
  }
}

/// Card + placeholder bars: the [Shimmer] covers the bars only, so the sweep
/// reads as a pending surface instead of recolouring the card itself.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const _Bars(),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Row(
        children: [
          ShimmerBox(width: 54, height: 54, shape: BoxShape.circle),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 16),
                SizedBox(height: 8),
                ShimmerBox(width: 100, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Guided empty state: the next action, then the control that does it.
class MemberEmpty extends StatelessWidget {
  const MemberEmpty({
    super.key,
    required this.query,
    required this.onCreate,
  });

  final String query;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    return ScrollableStateBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center,
              size: 48, color: context.palette.secondary),
          const SizedBox(height: 16),
          Text(
            searching ? 'No one matches "$query"' : 'Add your first member',
            style: TextStyle(
              color: context.palette.text,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? 'Search another name or phone number.'
                : 'Track dues and renewals for this gym.',
            style: TextStyle(color: context.palette.secondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (!searching)
            SizedBox(
              height: 48,
              child: TapScale(
                // The create flow fires Haptics.sheet() when the sheet arrives.
                enableHaptic: false,
                child: FilledButton(
                  onPressed: onCreate,
                  child: const Text('Add member'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Error state: what happened → what to do → the control that does it.
class MemberError extends StatelessWidget {
  const MemberError({
    super.key,
    this.title = "Couldn't load members",
    required this.onRetry,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ScrollableStateBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: context.palette.error),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: context.palette.text,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection, then try again.',
            style: TextStyle(color: context.palette.secondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: TapScale(
              child: OutlinedButton(
                onPressed: () {
                  Haptics.impact();
                  onRetry();
                },
                child: const Text('Retry'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompt shown when no single gym is selected (other tabs filter to one
/// gym; Home alone aggregates "All gyms").
class PickGymPrompt extends StatelessWidget {
  const PickGymPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return ScrollableStateBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store, size: 48, color: context.palette.secondary),
          const SizedBox(height: 16),
          Text(
            'Pick a gym to see its members',
            style: TextStyle(
              color: context.palette.text,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Use the gym switcher in the header.',
            style: TextStyle(color: context.palette.secondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
