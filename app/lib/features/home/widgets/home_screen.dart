/// Home tab: dues triage feed (DESIGN.md §3).
///
/// Header owns the gym switcher and the profile entry point; this screen
/// reads the selected gym id (`null` = All gyms → aggregate). Feed renders
/// Overdue, then Due ≤7d, then Active, each as a section with a count chip
/// that counts up only when the count changes. Cards carry Renew (opens
/// [RenewSheet] and refreshes the feed on close), Call, WhatsApp, and open the
/// member's record. Skeleton while loading, guided-empty (create the first
/// gym when the Owner has none, else add a member) when bare, and
/// error-retry on failure. Screen padding 20–24, 8px gaps, safe-area. Motion
/// comes from `core/motion`; all colours from [AppPalette].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../gyms/data/selected_gym.dart';
import '../../gyms/providers/gyms_providers.dart' show gymsListProvider;
import '../../gyms/widgets/gym_switcher.dart';
import '../../members/models/member.dart';
import '../../members/widgets/due_cue.dart';
import '../../members/widgets/member_detail_screen.dart';
import '../../members/widgets/member_form_sheet.dart';
import '../data/dues_providers.dart';
import 'dues_card.dart';
import 'dues_states.dart';

String _bucketTitle(DueBucket bucket) => switch (bucket) {
      DueBucket.overdue => 'Overdue',
      DueBucket.dueSoon => 'Due soon',
      DueBucket.active => 'Active',
    };

/// Home dues feed. [onOpenMember] lets the app shell push the detail
/// route; defaults to a [MaterialPageRoute] to [MemberDetailScreen].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onOpenMember});

  final void Function(BuildContext context, DuesEntry entry)? onOpenMember;

  void _openAddMember(BuildContext context, String gymId) {
    // A modal surface is arriving: one press, one haptic.
    Haptics.sheet();
    showAppSheet<void>(
      context,
      builder: (_) => MemberFormSheet(gymId: gymId),
    );
  }

  void _openGyms(BuildContext context) {
    // A control was pressed; the screen that follows is the visible change.
    Haptics.impact();
    context.push('/gyms');
  }

  void _openDetail(BuildContext context, DuesEntry e) {
    if (onOpenMember != null) {
      onOpenMember!(context, e);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberDetailScreen(
          gymId: e.member.gymId,
          memberId: e.member.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGymIdProvider);
    final sections = ref.watch(duesSectionsProvider);
    // Owner with zero gyms: the empty feed must guide gym creation, not
    // member creation (there is no gym to add a member to).
    final noGyms = ref.watch(gymsListProvider).value?.isEmpty ?? false;

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                12,
                AppSpace.screen,
                AppSpace.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dues',
                      style: AppType.title
                          .copyWith(color: context.palette.text),
                    ),
                  ),
                  const GymSwitcher(),
                  const SizedBox(width: AppSpace.sm),
                  const _ProfileButton(),
                ],
              ),
            ),
            Expanded(
              child: sections.when(
                skipLoadingOnReload: true,
                loading: () => const DuesSkeleton(),
                error: (_, _) => DuesError(
                  onRetry: () {
                    // A control was pressed; the skeleton that follows is the
                    // visible change.
                    Haptics.impact();
                    invalidateDuesViews(ref);
                  },
                ),
                data: (list) {
                  final total =
                      list.fold<int>(0, (n, s) => n + s.entries.length);
                  if (total == 0) {
                    return DuesEmpty(
                      allGyms: selected == null,
                      onAddGym: noGyms ? () => _openGyms(context) : null,
                      onAddMember: selected == null
                          ? null
                          : () => _openAddMember(context, selected),
                    );
                  }
                  // One entrance per visit: sections and their cards rise in
                  // feed order, ~40ms apart (the primitive clamps the tail).
                  var index = 0;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.screen,
                      AppSpace.md,
                      AppSpace.screen,
                      AppSpace.lg,
                    ),
                    children: [
                      for (final section in list)
                        if (section.entries.isNotEmpty) ...[
                          StaggeredEntrance(
                            index: index++,
                            child: _SectionHeader(
                              bucket: section.bucket,
                              count: section.entries.length,
                            ),
                          ),
                          const SizedBox(height: AppSpace.gap),
                          for (final entry in section.entries)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpace.gap,
                              ),
                              child: DuesCard(
                                entry: entry,
                                index: index++,
                                onTap: () => _openDetail(context, entry),
                              ),
                            ),
                          const SizedBox(height: AppSpace.sm),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 44x44 header avatar → `/profile` (route owned by the app shell).
class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TapScale(
      // The InkWell owns the tap; TapScale adds the press scale.
      onTap: null,
      scale: 0.94,
      dimOpacity: 0.94,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: palette.surface,
          shape: CircleBorder(side: BorderSide(color: palette.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // A destination change — the same meaning as a tab move.
              Haptics.select();
              context.push('/profile');
            },
            child: Icon(
              Icons.person_outline,
              size: 22,
              color: palette.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.bucket, required this.count});

  final DueBucket bucket;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dueColor(bucket),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(
          _bucketTitle(bucket),
          style: AppType.subtitle.copyWith(color: palette.text),
        ),
        const SizedBox(width: AppSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: palette.border),
          ),
          // Shows its real value on the first frame; rolls only on a change.
          child: AnimatedCounter(
            value: count,
            initialValue: count,
            style: AppType.caption.copyWith(color: palette.secondary),
          ),
        ),
      ],
    );
  }
}
