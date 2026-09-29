import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/scrollable_state_body.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/gyms_providers.dart';

/// Owner's gym list: create / rename / delete.
///
/// The accent FAB (`Add gym`) is the always-visible create affordance, so the
/// Owner can add a 2nd, 3rd, nth gym while the list is populated; the empty
/// state repeats it as `Add gym`. Rows take the shared press scale and open the
/// rename dialog; a left swipe deletes behind a destructive confirm. Every
/// dialog arrival fires [Haptics.sheet] (a modal surface came up), a refused
/// delete fires [Haptics.error]. Colours come from [AppPalette]; every mutation
/// invalidates [gymsListProvider] so the list and switcher refetch.
class GymsScreen extends ConsumerWidget {
  const GymsScreen({super.key});

  Future<void> _showNameDialog(
    BuildContext context,
    WidgetRef ref, {
    Gym? existing,
  }) async {
    // Plain local state instead of a TextEditingController: a controller
    // created out here would have to be disposed the moment `showDialog`
    // resolves, while the dialog route is still animating out and rebuilding
    // its field (that is a real "used after being disposed" crash).
    final formKey = GlobalKey<FormState>();
    var name = existing?.name ?? '';
    // A modal surface is arriving.
    Haptics.sheet();
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add gym' : 'Rename gym'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Gym name'),
            onChanged: (v) => name = v,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a gym name.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, name.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (submitted == null || submitted.isEmpty) return;
    final repo = ref.read(gymsRepositoryProvider);
    if (repo == null) return;
    if (existing == null) {
      await repo.createGym(submitted);
    } else {
      await repo.renameGym(id: existing.id, name: submitted);
    }
    // Committed: the dialog closed, the new name arrives with the refetch.
    Haptics.success();
    ref.invalidate(gymsListProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Gym gym) async {
    Haptics.sheet();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${gym.name}?'),
        content: const Text('Its members, plans and dues are deleted with it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              // Destructive fill overrides the theme's accent; the label
              // mirrors `ColorScheme.onError`.
              backgroundColor: context.palette.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 44),
            ),
            onPressed: () {
              // Destructive commitment accepted.
              Haptics.impact(strength: HapticStrength.heavy);
              Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(gymsRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.deleteGym(gym.id);
    } catch (_) {
      // Refused, and never silent: the swipe snaps back with an error.
      Haptics.error();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't delete the gym. Check your connection, then try again.",
          ),
        ),
      );
      return;
    }
    ref.invalidate(gymsListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyms = ref.watch(gymsListProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('Your gyms'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () {
              // A heavy commitment: the session ends here, no confirm step.
              Haptics.impact(strength: HapticStrength.heavy);
              ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      // The FAB owns the modal arrival haptic (see `_showNameDialog`), so the
      // press itself is scale only.
      floatingActionButton: TapScale(
        onTap: null,
        dimOpacity: 0.94,
        child: FloatingActionButton.extended(
          onPressed: () => _showNameDialog(context, ref),
          tooltip: 'Add gym',
          icon: const Icon(Icons.add),
          label: const Text('Add gym'),
        ),
      ),
      body: SafeArea(
        child: gyms.when(
          skipLoadingOnReload: true,
          loading: () => const _GymsSkeleton(),
          error: (_, _) => ScrollableStateBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: palette.error),
                const SizedBox(height: AppSpace.md),
                Text(
                  "Couldn't load your gyms.",
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
                TapScale(
                  onTap: null,
                  dimOpacity: 0.94,
                  child: FilledButton(
                    onPressed: () {
                      // A control was pressed; the skeleton that follows is
                      // the visible change.
                      Haptics.impact();
                      ref.invalidate(gymsListProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ScrollableStateBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add your first gym to start tracking dues.',
                      style: AppType.subtitle.copyWith(color: palette.text),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.md),
                    TapScale(
                      onTap: null,
                      dimOpacity: 0.94,
                      child: FilledButton(
                        onPressed: () => _showNameDialog(context, ref),
                        child: const Text('Add gym'),
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.sm,
                AppSpace.screen,
                96,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.gap),
              itemBuilder: (context, i) {
                final gym = list[i];
                // One entrance per visit, ~40ms behind the row above.
                return StaggeredEntrance(
                  index: i,
                  child: Dismissible(
                    key: ValueKey(gym.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpace.screen),
                      child: Icon(Icons.delete, color: palette.error),
                    ),
                    confirmDismiss: (_) async {
                      await _confirmDelete(context, ref, gym);
                      return false;
                    },
                    child: PressableRow(
                      // The row is one control (open this gym to rename it);
                      // its haptic is the dialog's arrival, so the press itself
                      // only animates.
                      onTap: () =>
                          _showNameDialog(context, ref, existing: gym),
                      enableHaptic: false,
                      // Zero padding: the ListTile keeps its own row metrics,
                      // and the press surface hugs them.
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        // Row text/icon colours come from
                        // AppTheme.listTileTheme.
                        title: Text(gym.name),
                        trailing: IconButton(
                          tooltip: 'Rename',
                          onPressed: () =>
                              _showNameDialog(context, ref, existing: gym),
                          icon: const Icon(Icons.edit),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// First-load skeleton for the gym list: 3 surface cards matching the loaded
/// `PressableRow` rows (same radius/64dp height, 8px gaps), so the swap to real
/// rows does not shift layout. The placeholder bars stream through the shared
/// [Shimmer]; the card surfaces stay outside it.
class _GymsSkeleton extends StatelessWidget {
  const _GymsSkeleton();

  static const _rows = 3;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.sm,
        AppSpace.screen,
        96,
      ),
      itemCount: _rows,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.gap),
      itemBuilder: (_, _) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Shimmer(
          child: Row(
            children: [
              ShimmerBox(width: 140, height: 14),
              Spacer(),
              ShimmerBox(width: 18, height: 18, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
