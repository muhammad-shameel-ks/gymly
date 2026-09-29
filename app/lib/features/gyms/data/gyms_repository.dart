import 'package:supabase_flutter/supabase_flutter.dart';

import 'gym.dart';

/// CRUD for `gyms`, always scoped to one Owner (`owner_id = auth.uid()`,
/// matching the `gyms_owner_all` RLS policy).
class GymsRepository {
  GymsRepository(this._client, this._ownerId);

  final SupabaseClient _client;
  final String _ownerId;

  static const _columns = 'id,owner_id,name';

  static List<Gym> _parseList(List<dynamic> rows) => rows
      .map((r) => Gym.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();

  Future<List<Gym>> listGyms() async {
    final rows = await _client
        .from('gyms')
        .select(_columns)
        .eq('owner_id', _ownerId)
        .order('name');
    return _parseList(rows as List);
  }

  Future<Gym> createGym(String name) async {
    final row = await _client
        .from('gyms')
        .insert({'owner_id': _ownerId, 'name': name.trim()})
        .select(_columns)
        .single();
    return Gym.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> renameGym({required String id, required String name}) async {
    await _client
        .from('gyms')
        .update({'name': name.trim()})
        .eq('id', id)
        .eq('owner_id', _ownerId);
  }

  Future<void> deleteGym(String id) async {
    await _client
        .from('gyms')
        .delete()
        .eq('id', id)
        .eq('owner_id', _ownerId);
  }
}
