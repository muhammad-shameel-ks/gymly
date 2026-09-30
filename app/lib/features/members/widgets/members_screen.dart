/// Members tab: search-first list filtered by gym, with the signature due ring.
///
/// Requires a single [gymId]; a null gym shows [PickGymPrompt] (other tabs
/// filter to one gym — only Home aggregates "All gyms").
/// Each row is a [MemberWithDues]: the ring fills with the paid share of his tab
/// (`tab.ringFill`), the money line reads `₹2,000 pending · due 12 Oct` (the
/// same wording as the Home card), and a member who has stopped carries the
/// `Cancelled` badge. Adding a member is the tab's FAB — same place, same
/// dimmed-when-gym-less treatment as the Leads tab — plus the empty state's own
/// CTA; search is the shared [AppSearchBar], so members and leads are
/// pixel-identical. Tapping a row pushes [MemberDetailScreen]; rows stagger in
/// once per visit. The last loaded rows stay on screen while the next query
/// loads, so typing never flashes a skeleton and never replays that entrance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_search_bar.dart';
import '../../../core/widgets/app_sheet.dart';
import '../models/member.dart';
import '../providers/members_providers.dart';
import 'due_cue.dart';
import 'member_detail_screen.dart';
import 'member_form_sheet.dart';
import 'member_states.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, required this.gymId});

  /// Null = "All gyms" selected → prompt to pick one gym.
  final String? gymId;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// Last non-empty result, kept while the next query loads.
  List<MemberWithDues>? _rows;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final gymId = widget.gymId;
    if (gymId == null) return;
    Haptics.sheet();
    final open = await showAppSheet<Member>(
      context,
      builder: (_) => MemberFormSheet(gymId: gymId),
    );
    // The sheet answered "that phone is already a member — open them instead":
    // the push belongs to this tab's stack, and the sheet itself lives on the
    // root navigator (above the whole shell), so it cannot do it.
    if (open == null || !mounted) return;
    Haptics.impact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MemberDetailScreen(gymId: open.gymId, memberId: open.id),
      ),
    );
  }

  Widget _list(List<MemberWithDues> rows, String gymId) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      // FAB height plus a token gap: the last row never hides under it.
      padding: const EdgeInsets.only(bottom: 56 + AppSpace.lg),
      itemBuilder: (_, i) {
        final e = rows[i];
        return StaggeredEntrance(
          index: i,
          child: _MemberRow(
            entry: e,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemberDetailScreen(
                  gymId: gymId,
                  memberId: e.member.id,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The add-member action, in the thumb zone on every list state — the same
  /// place the Leads tab puts its own (item 1). With no gym selected it stays
  /// visible but dimmed and inert, so it still reads as the way to add a member.
  Widget _addFab(bool canAdd) {
    final palette = context.palette;
    return TapScale(
      enabled: canAdd,
      // The create flow fires Haptics.sheet() when the sheet arrives.
      enableHaptic: false,
      child: FloatingActionButton.extended(
        onPressed: canAdd ? _openCreate : null,
        // Disabled reads as disabled: dimmed fill, flat, no ripple (the
        // framework drops the ink when `onPressed` is null).
        backgroundColor: canAdd ? palette.accent : palette.border,
        foregroundColor: canAdd ? palette.onAccent : palette.secondary,
        elevation: canAdd ? null : 0,
        focusElevation: canAdd ? null : 0,
        hoverElevation: canAdd ? null : 0,
        highlightElevation: canAdd ? null : 0,
        disabledElevation: 0,
        icon: Icon(
          Icons.add,
          color: canAdd ? palette.onAccent : palette.secondary,
        ),
        label: const Text('Add member'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gymId = widget.gymId;
    if (gymId == null) {
      return Scaffold(
        backgroundColor: context.palette.bg,
        floatingActionButton: _addFab(false),
        body: const PickGymPrompt(),
      );
    }
    final q = (gymId: gymId, query: _query);
    final list = ref.watch(membersListProvider(q));

    return Scaffold(
      backgroundColor: context.palette.bg,
      floatingActionButton: _addFab(true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              AppSearchBar(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: list.when(
                  skipLoadingOnReload: true,
                  loading: () {
                    final rows = _rows;
                    return rows == null
                        ? const MemberListSkeleton()
                        : _list(rows, gymId);
                  },
                  error: (_, _) => MemberError(
                    onRetry: () => ref.invalidate(membersListProvider(q)),
                  ),
                  data: (rows) {
                    _rows = rows.isEmpty ? null : rows;
                    if (rows.isEmpty) {
                      return MemberEmpty(
                        query: _query,
                        onCreate: _openCreate,
                      );
                    }
                    return _list(rows, gymId);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.entry, required this.onTap});

  final MemberWithDues entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // A member whose tab has stopped: nothing in force today and the last
    // stretch ended `cancelled` — which is what `MemberTab.payableTo` records.
    final cancelled = entry.tab.payableTo != null;
    return PressableRow(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            MemberAvatar(entry: entry),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.member.name,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (cancelled) ...[
                        const SizedBox(width: AppSpace.sm),
                        const MemberCancelledBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.member.phone} · ${moneyLine(entry.tab)}',
                    style: TextStyle(
                      color: palette.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
