/// Leads tab: search + status filter chips + inquiry list.
///
/// The search field filters the already status-filtered list locally (name, or
/// phone digits), so a keystroke never re-queries: the skeleton and the list's
/// scroll position survive typing. The status counts stay whole-gym.
///
/// List states: skeleton while loading, guided empty (nothing yet, nothing for
/// this status, nothing matching the search), error + retry.
/// Motion: chips press (TapScale) + select haptic, counts count up, one
/// staggered entrance per visit, skeletons stream.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_search_bar.dart';
import '../../../core/widgets/scrollable_state_body.dart';
import '../../gyms/widgets/gym_switcher.dart';
import '../application/leads_providers.dart';
import '../data/inquiry.dart';
import 'inquiry_card.dart';
import 'quick_add_sheet.dart';

/// Case-insensitive name match, or a digits-only phone match: `98 123` finds
/// `+91 98123 45678`.
List<Inquiry> _matching(List<Inquiry> inquiries, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return inquiries;
  final digits = q.replaceAll(RegExp(r'\D'), '');
  return [
    for (final inquiry in inquiries)
      if (inquiry.name.toLowerCase().contains(q) ||
          (digits.isNotEmpty &&
              inquiry.phone.replaceAll(RegExp(r'\D'), '').contains(digits)))
        inquiry,
  ];
}

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  final _search = TextEditingController();

  /// Search text, held here (never in a provider keyed by it) so typing
  /// rebuilds the list body only and cannot restart the fetch.
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gymId = ref.watch(selectedGymIdProvider);
    final inquiries = ref.watch(filteredInquiriesProvider);
    final async = ref.watch(inquiriesProvider);
    final filter = ref.watch(leadFilterProvider);
    final counts = ref.watch(leadCountsProvider);
    final canAdd = gymId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Leads',
            style: AppType.title.copyWith(color: context.palette.text)),
        actions: const [
          // The empty state sends the owner to the header, so the switcher
          // lives here: same 44dp target and 20px inset as the shell headers.
          Padding(
            padding: EdgeInsets.only(right: AppSpace.screen),
            child: SizedBox(height: 44, child: Center(child: GymSwitcher())),
          ),
        ],
      ),
      floatingActionButton: TapScale(
        // Press feedback only; the sheet fires its own arrival haptic.
        enabled: canAdd,
        child: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: canAdd ? () => showQuickAddSheet(context) : null,
            // Disabled reads as disabled: dimmed fill, flat, no ripple (the
            // framework drops the ink when `onPressed` is null).
            backgroundColor:
                canAdd ? context.palette.accent : context.palette.border,
            foregroundColor:
                canAdd ? context.palette.onAccent : context.palette.secondary,
            elevation: canAdd ? null : 0,
            focusElevation: canAdd ? null : 0,
            hoverElevation: canAdd ? null : 0,
            highlightElevation: canAdd ? null : 0,
            disabledElevation: 0,
            child: Icon(Icons.add,
                color: canAdd
                    ? context.palette.onAccent
                    : context.palette.secondary),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (gymId == null)
                // Bounded slot, so the hint can scroll instead of pushing
                // the tab body past its height.
                const Expanded(child: _PickGymHint())
              else ...[
                _StatusChips(
                  selected: filter,
                  counts: counts,
                  onSelect: (s) =>
                      ref.read(leadFilterProvider.notifier).state = s,
                ),
                const SizedBox(height: AppSpace.sm),
                AppSearchBar(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: AppSpace.md),
                Expanded(
                  child: async.when(
                    skipLoadingOnReload: true,
                    loading: () => const _LeadsSkeleton(),
                    error: (e, _) => _LeadsError(
                      message: "Couldn't load leads.",
                      onRetry: () => ref.invalidate(inquiriesProvider),
                    ),
                    data: (_) {
                      final visible = _matching(inquiries, _query);
                      if (visible.isEmpty) {
                        return _LeadsEmpty(
                          query: _query,
                          filtered: filter != null,
                          onAdd: () => showQuickAddSheet(context),
                          onClearFilter: () {
                            Haptics.select();
                            ref.read(leadFilterProvider.notifier).state = null;
                          },
                          onClearSearch: () {
                            Haptics.select();
                            _search.clear();
                            setState(() => _query = '');
                          },
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(inquiriesProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpace.sm),
                          itemBuilder: (context, i) {
                            final inquiry = visible[i];
                            return StaggeredEntrance(
                              key: ValueKey(inquiry.id),
                              index: i,
                              child: InquiryCard(inquiry: inquiry),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickGymHint extends StatelessWidget {
  const _PickGymHint();

  @override
  Widget build(BuildContext context) {
    return ScrollableStateBody(
      // Inline hint: stays at the top of the tab (the body already carries
      // the screen padding) and scrolls only if the viewport is too short.
      alignment: Alignment.topCenter,
      padding: EdgeInsets.zero,
      child: RiseIn(
        child: SizedBox(
          width: double.infinity,
          child: Card(
            color: context.palette.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Text(
                'Pick a gym from the header to see leads.',
                style: AppType.body.copyWith(color: context.palette.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final InquiryStatus? selected;
  final Map<InquiryStatus, int> counts;
  final ValueChanged<InquiryStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, InquiryStatus? status) {
      final isActive = selected == status;
      final count = status == null
          ? counts.values.fold<int>(0, (a, b) => a + b)
          : (counts[status] ?? 0);
      final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
        color: isActive
            ? context.palette.onAccent
            : context.palette.secondary,
      );
      return TapScale(
        // Press feedback; the select haptic belongs to the chip moving.
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              Text(' · '),
              AnimatedCounter(value: count, style: labelStyle),
            ],
          ),
          selected: isActive,
          selectedColor: context.palette.accent,
          labelStyle: labelStyle,
          checkmarkColor: context.palette.onAccent,
          onSelected: (_) {
            if (isActive) return;
            Haptics.select();
            onSelect(status);
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', null),
          const SizedBox(width: AppSpace.sm),
          chip('New', InquiryStatus.fresh),
          const SizedBox(width: AppSpace.sm),
          chip('Contacted', InquiryStatus.contacted),
          const SizedBox(width: AppSpace.sm),
          chip('Joined', InquiryStatus.joined),
          const SizedBox(width: AppSpace.sm),
          chip('Lost', InquiryStatus.lost),
        ],
      ),
    );
  }
}

class _LeadsSkeleton extends StatelessWidget {
  const _LeadsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
        itemBuilder: (context, _) => Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  ShimmerBox(width: 140, height: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ShimmerBox(
                          width: 64, height: 22, radius: AppRadius.pill),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              ShimmerBox(width: 108, height: 12),
              SizedBox(height: AppSpace.sm + 4),
              Row(
                children: [
                  ShimmerBox(width: 44, height: 44, shape: BoxShape.circle),
                  SizedBox(width: AppSpace.sm),
                  ShimmerBox(width: 44, height: 44, shape: BoxShape.circle),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ShimmerBox(width: 120, height: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadsEmpty extends StatelessWidget {
  const _LeadsEmpty({
    required this.query,
    required this.filtered,
    required this.onAdd,
    required this.onClearFilter,
    required this.onClearSearch,
  });

  /// The live search text; non-empty makes the state "nothing matched".
  final String query;

  /// Whether a status chip is narrowing the list.
  final bool filtered;

  final VoidCallback onAdd;
  final VoidCallback onClearFilter;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String body;
    final String action;
    final VoidCallback onPressed;
    // Search first: it is the narrowest narrowing, and the one just touched.
    if (query.trim().isNotEmpty) {
      title = 'No leads match "${query.trim()}"';
      body = 'Clear the search to see every lead.';
      action = 'Clear search';
      onPressed = onClearSearch;
    } else if (filtered) {
      title = 'No leads with this status.';
      body = 'Clear the filter to see every lead.';
      action = 'Show all leads';
      onPressed = onClearFilter;
    } else {
      title = 'No leads yet.';
      body = 'Add a walk-in with just a name and phone.';
      action = 'Add lead';
      onPressed = onAdd;
    }

    return ScrollableStateBody(
      child: RiseIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppType.subtitle.copyWith(color: context.palette.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              body,
              style: AppType.caption.copyWith(color: context.palette.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.md),
            TapScale(
              // Press feedback; the control fires its own select haptic.
              child: FilledButton(
                onPressed: onPressed,
                child: Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadsError extends StatelessWidget {
  const _LeadsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ScrollableStateBody(
      child: RiseIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: context.palette.error, size: 32),
            const SizedBox(height: AppSpace.sm),
            Text(message,
                style: AppType.body.copyWith(color: context.palette.text),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Check your connection, then try again.',
              style: AppType.caption.copyWith(color: context.palette.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.md),
            TapScale(
              child: OutlinedButton(
                onPressed: () {
                  Haptics.impact();
                  onRetry();
                },
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
