import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/gym.dart';
import '../data/gyms_repository.dart';

export '../data/gym.dart';
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
final gymsListProvider = FutureProvider<List<Gym>>((ref) async {
  final repo = ref.watch(gymsRepositoryProvider);
  if (repo == null) return const <Gym>[];
  return repo.listGyms();
});
