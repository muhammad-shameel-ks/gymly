/// Home list states: skeleton + guided-empty + error-retry.
///
/// Every Home feed renders one of these. The skeleton mirrors the dues-card
/// geometry and streams through [Shimmer] — the app's only loop, scoped to the
/// placeholder bars so the card surfaces keep their own fill. The empty state
/// says the next action in the owner's words (`docs/voice.md` rule 5) and its
/// icon rises in once per visit; the error state is what happened → what to do
/// → the control. Motion comes from `core/motion`; all colours from
/// [AppPalette].
library;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/scrollable_state_body.dart';

/// Skeleton rows mirroring the dues-card layout.
class DuesSkeleton extends StatelessWidget {
  const DuesSkeleton({super.key, this.rows = 6});

  final int rows;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.md,
        AppSpace.screen,
        AppSpace.lg,
      ),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.gap),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 140, height: 16),
              SizedBox(height: AppSpace.sm),
              ShimmerBox(width: 100, height: 13),
              SizedBox(height: AppSpace.sm + AppSpace.xs),
              ShimmerBox(width: double.infinity, height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guided empty state. What it guides depends on why the feed is empty:
///
/// 1. [onAddGym] non-null → the Owner has **no gyms at all**: create the
///    first one (accent CTA 'Add gym').
/// 2. else [onAddMember] non-null → a gym is in scope but has **no members**:
///    add its first member.
/// 3. else → the triage is empty because nothing is due: the healthy state,
///    said plainly, with no CTA (the next action is the feed itself).
class DuesEmpty extends StatelessWidget {
  const DuesEmpty({super.key, this.onAddMember, this.onAddGym});

  /// Non-null when a single gym is in scope and has no members yet; null when
  /// All gyms is selected (the switcher above the feed picks the gym).
  final VoidCallback? onAddMember;

  /// Non-null when the Owner owns zero gyms: the next action is creating one,
  /// not adding a member. Takes precedence over [onAddMember].
  final VoidCallback? onAddGym;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final noGyms = onAddGym != null;
    final noMembers = !noGyms && onAddMember != null;
    return ScrollableStateBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One-shot entrance, once per visit: a rise, never a loop.
          RiseIn(
            child: Icon(
              noGyms
                  ? Icons.storefront_outlined
                  : noMembers
                      ? Icons.fitness_center
                      : Icons.check_circle_outline,
              size: 48,
              color: palette.secondary,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            noGyms
                ? 'Add your first gym to start tracking dues.'
                : noMembers
                    ? 'Add your first member to start tracking dues.'
                    : 'Nothing due today.',
            style: AppType.subtitle.copyWith(color: palette.text),
            textAlign: TextAlign.center,
          ),
          if (noGyms) ...[
            const SizedBox(height: AppSpace.md),
            TapScale(
              onTap: null,
              dimOpacity: 0.94,
              child: FilledButton(
                onPressed: onAddGym,
                child: const Text('Add gym'),
              ),
            ),
          ] else if (noMembers) ...[
            const SizedBox(height: AppSpace.md),
            TapScale(
              onTap: null,
              dimOpacity: 0.94,
              child: FilledButton(
                onPressed: onAddMember,
                child: const Text('Add member'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state: what happened → what to do → the control that does it.
class DuesError extends StatelessWidget {
  const DuesError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ScrollableStateBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: palette.error),
          const SizedBox(height: AppSpace.md),
          Text(
            "Couldn't load dues.",
            style: AppType.subtitle.copyWith(color: palette.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Check your connection, then try again.',
            style: AppType.body.copyWith(color: palette.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 48,
            child: TapScale(
              onTap: null,
              dimOpacity: 0.94,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
