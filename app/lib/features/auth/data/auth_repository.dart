import 'package:supabase_flutter/supabase_flutter.dart';

/// Email/password auth for the Owner (the only login role in v1).
/// Session persistence is handled by supabase_flutter (auto-refresh + local
/// storage); [authStateChanges] re-emits on app start when a session exists.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  /// Supabase Auth user id == `gyms.owner_id`.
  String? get currentOwnerId => _client.auth.currentUser?.id;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email.trim(), password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
