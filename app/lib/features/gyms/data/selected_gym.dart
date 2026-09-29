/// Persisted gym selection: the gym the Owner is working in, or `null` for
/// All gyms (Home aggregates across gyms when null).
///
/// [sharedPreferencesProvider] is overridden in `main.dart` with an instance
/// already loaded before `runApp`, so [SelectedGymIdNotifier.build] reads the
/// stored id synchronously — the very first frame is already scoped to the gym
/// the Owner picked last (no drop back to All gyms on launch).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode.dart';

/// Selected gym id; `null` = All gyms.
final selectedGymIdProvider =
    NotifierProvider<SelectedGymIdNotifier, String?>(
        SelectedGymIdNotifier.new);

/// Reads, writes and retires the persisted selection.
///
/// [setGym] is the single mutation path, so the state and the stored key can
/// never disagree. A selection only means something inside the Owner's gym
/// list, so it is retired the moment it stops being visible: [validateAgainst]
/// falls back to All gyms when a resolved list does not contain it (deleted
/// gym, or a different account signed in), and the sign-out paths clear it
/// outright.
class SelectedGymIdNotifier extends Notifier<String?> {
  /// SharedPreferences key; a gym id, or absent for All gyms.
  static const String key = 'gymly.selected_gym_id';

  @override
  String? build() => ref.read(sharedPreferencesProvider).getString(key);

  /// Selects [id] (`null` = All gyms) and persists it. Every writer — the
  /// switcher, gym creation, sign-out — comes through here.
  Future<void> setGym(String? id) async {
    if (state == id) return;
    state = id;
    final prefs = ref.read(sharedPreferencesProvider);
    if (id == null) {
      // All gyms is the *absence* of a selection, so the key is removed
      // rather than stored as an empty value.
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  /// Falls back to All gyms while the selection is not among [visibleGymIds],
  /// the gyms the Owner's list just resolved to. Called with that list, so a
  /// deleted gym (or an id belonging to another account) retires itself
  /// instead of leaving the app scoped to a gym the Owner cannot see.
  ///
  /// No-op while the selection is All gyms or still visible.
  Future<void> validateAgainst(Iterable<String> visibleGymIds) async {
    final selected = state;
    if (selected == null || visibleGymIds.contains(selected)) return;
    await setGym(null);
  }
}
