/// Riverpod providers for the plans slice (dependency-free).
///
/// Only `flutter_riverpod` + `supabase_flutter` imports. Foundation may
/// later replace [plansSupabaseClient] with the shared client; the
/// repository + list providers below keep their names.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/plans_repository.dart';
import '../models/plan.dart';

/// Raw Supabase client. Foundation can override this with a shared provider.
final plansSupabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
  name: 'plansSupabaseClient',
);

final plansRepositoryProvider = Provider<PlansRepository>(
  (ref) => PlansRepository(ref.watch(plansSupabaseClientProvider)),
  name: 'plansRepository',
);

/// Plan list for one gym (cheapest first). Scoped by [gymId]; callers
/// outside the Plans tab (members/leads pickers) reuse this provider.
final plansListProvider = FutureProvider.family<List<Plan>, String>(
  (ref, gymId) =>
      ref.watch(plansRepositoryProvider).listPlans(gymId: gymId),
  name: 'plansList',
);

/// Invalidate the plan list after any write.
void invalidatePlanViews(WidgetRef ref) {
  ref.invalidate(plansListProvider);
}
