import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/gym.dart';
import '../data/gyms_repository.dart';
import '../data/selected_gym.dart';

export '../data/gym.dart';
// Canonical, persisted gym selection; re-exported so the gyms slice exposes a
// single import surface to its consumers.
export '../data/selected_gym.dart';

/// Null while logged out — every query is scoped `owner_id = auth.uid()`.
final gymsRepositoryProvider = Provider<GymsRepository?>((ref) {
  final ownerId = ref.watch(currentOwnerIdProvider);
  if (ownerId == null) return null;
  return GymsRepository(ref.watch(supabaseClientProvider), ownerId);
});

/// Owner's gyms for the switcher + gyms screen.
///
/// Plain one-shot fetch (no realtime): refreshes via `ref.invalidate`
/// after any gym mutation. Resolves to an empty list while logged out so
/// dependents (`duesScopeProvider`) never hang.
///
/// The resolved list is also what validates the persisted selection: a stored
/// gym that is not in it (deleted gym, or a different account signed in) falls
/// back to All gyms — see [SelectedGymIdNotifier.validateAgainst].
final gymsListProvider = FutureProvider<List<Gym>>((ref) async {
  final repo = ref.watch(gymsRepositoryProvider);
  // No owner yet (logged out, or the persisted session is still restoring):
  // this empty list is a placeholder, not a gym list, so the selection is left
  // untouched rather than validated against nothing.
  if (repo == null) return const <Gym>[];

  final gyms = await repo.listGyms();
  // A `ref.invalidate` during the fetch supersedes this list (its ref is no
  // longer mounted): the newest build validates instead, so a stale result can
  // never retire a fresh pick.
  if (!ref.mounted) return gyms;

  // Fire-and-forget: `validateAgainst` corrects the selection synchronously,
  // and a storage hiccup must not fail the gym list itself.
  final visibleIds = [for (final gym in gyms) gym.id];
  unawaited(
    ref.read(selectedGymIdProvider.notifier).validateAgainst(visibleIds),
  );
  return gyms;
});
