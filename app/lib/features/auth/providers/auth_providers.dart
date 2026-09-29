import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Shared Supabase client (initialised in `main.dart` by foundation).
final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Re-emits on sign-in/sign-out; also fires once with the persisted session
/// (if any) on app start, which is what keeps the Owner logged in.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Owner id used to scope every query (`owner_id = auth.uid()`).
/// Falls back to the synchronously-available persisted session while the
/// auth stream is still loading, so gated screens don't flash a login page.
final currentOwnerIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authStateProvider).value?.session ??
      Supabase.instance.client.auth.currentSession;
  return session?.user.id;
});

final isLoggedInProvider =
    Provider<bool>((ref) => ref.watch(currentOwnerIdProvider) != null);

/// Auth gate for the router.
///
/// Wire into GoRouter's `redirect`, e.g.:
/// ```dart
/// redirect: (context, state) {
///   final loggedIn = ref.read(isLoggedInProvider);
///   return authRedirect(loggedIn: loggedIn, location: state.matchedLocation);
/// },
/// ```
/// Logged-out owners go to `/login`; logged-in owners visiting `/login` or
/// `/signup` bounce to `/`.
String? authRedirect({required bool loggedIn, required String location}) {
  const publicRoutes = ['/login', '/signup'];
  if (!loggedIn && !publicRoutes.contains(location)) return '/login';
  if (loggedIn && publicRoutes.contains(location)) return '/';
  return null;
}
