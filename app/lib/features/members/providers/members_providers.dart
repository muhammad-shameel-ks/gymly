/// Riverpod providers for the members slice (dependency-free).
///
/// Only `flutter_riverpod` + `supabase_flutter` imports. Foundation may
/// later replace [supabaseClientProvider] with the shared client; the
/// repository + list/detail providers below keep their names.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/members_repository.dart';
import '../models/member.dart';

final _inr = NumberFormat.decimalPattern('en_IN');

/// Whole amounts print without decimals; anything else keeps its precision.
num _whole(num amount) => amount.remainder(1) == 0 ? amount.round() : amount;

/// Raw Supabase client. Foundation can override this with a shared provider.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
  name: 'membersSupabaseClient',
);

final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) => MembersRepository(ref.watch(supabaseClientProvider)),
  name: 'membersRepository',
);

/// List query key: gym scope + search text.
typedef MemberQuery = ({String gymId, String query});

/// Search-first member list with resolved current subscriptions.
final membersListProvider = FutureProvider.family<List<MemberWithDues>,
    MemberQuery>(
  (ref, q) => ref
      .watch(membersRepositoryProvider)
      .listMembers(gymId: q.gymId, query: q.query),
  name: 'membersList',
);

/// Detail payload: member + current subscription + history (desc).
final memberDetailProvider =
    FutureProvider.family<MemberWithDues, String>(
  (ref, memberId) =>
      ref.watch(membersRepositoryProvider).memberDetail(memberId),
  name: 'memberDetail',
);

/// Minimal plan option for pickers (avoids importing the plans slice).
class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.amount,
    required this.durationDays,
  });

  final String id;
  final String name;
  final num amount;
  final int durationDays;

  factory PlanOption.fromJson(Map<String, dynamic> json) => PlanOption(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: json['amount'] as num,
        durationDays: (json['duration_days'] as num).toInt(),
      );

  /// `Platinum · ₹3,333 · 90 days` — money, then term (voice rule 3).
  String get label => '$name · ₹${_inr.format(_whole(amount))}'
      ' · $durationDays ${durationDays == 1 ? 'day' : 'days'}';
}

/// Plans of one gym for the create/renew pickers.
final plansForGymProvider =
    FutureProvider.family<List<PlanOption>, String>(
  (ref, gymId) async {
    final rows = await ref
        .watch(supabaseClientProvider)
        .from('plans')
        .select('id,name,amount,duration_days')
        .eq('gym_id', gymId)
        .order('amount', ascending: true) as List<dynamic>;
    return rows
        .map((r) =>
            PlanOption.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
  },
  name: 'membersPlansForGym',
);

/// Invalidate list + detail after any write.
void invalidateMemberViews(WidgetRef ref, {required String gymId, String? memberId}) {
  ref.invalidate(membersListProvider);
  if (memberId != null) ref.invalidate(memberDetailProvider(memberId));
}
