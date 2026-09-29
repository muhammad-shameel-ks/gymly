/// Supabase bootstrap + typed table helpers (foundation-owned).
///
/// Slices keep their own `supabaseClientProvider`s (auth/members/plans/home
/// each default to [Supabase.instance.client]); this module only owns
/// initialization and table/column constants so queries stay typo-proof.
///
/// Config: `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`.
/// Defaults point at the Gymly project so `flutter run` works zero-config.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

const String _kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://uyqgvhaixjthbxrhbemc.supabase.co',
);

const String _kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV5cWd2aGFpeGp0aGJ4cmhiZW1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0MTc3OTQsImV4cCI6MjEwNTk5Mzc5NH0.ZCpyQxzWRHElZtDyFrjro-CijUv0M8cWR0O5BMz1YeY',
);

/// Initialize Supabase. Call once from `main()` before `runApp`.
Future<void> initSupabase() async {
  await Supabase.initialize(url: _kSupabaseUrl, anonKey: _kSupabaseAnonKey); // ignore: deprecated_member_use
}

/// Shortcut for `Supabase.instance.client`.
SupabaseClient get supabase => Supabase.instance.client;

/// Table names in `public` (DESIGN.md §2).
abstract final class SupabaseTables {
  static const String gyms = 'gyms';
  static const String plans = 'plans';
  static const String members = 'members';

  /// Stores Subscription rows (GLOSSARY.md); append-only per ADR-0001.
  static const String memberships = 'memberships';
  static const String inquiries = 'inquiries';
}

/// Shared column names to keep query filters typo-proof.
abstract final class SupabaseColumns {
  static const String id = 'id';
  static const String ownerId = 'owner_id';
  static const String gymId = 'gym_id';
  static const String memberId = 'member_id';
  static const String planId = 'plan_id';
  static const String startDate = 'start_date';
  static const String expiryDate = 'expiry_date';
  static const String name = 'name';
  static const String phone = 'phone';
  static const String status = 'status';
}
