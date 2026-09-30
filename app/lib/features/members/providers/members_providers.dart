/// Riverpod providers for the members slice.
///
/// Only `flutter_riverpod` + `supabase_flutter` imports plus the Home dues
/// slice (whose feed shows the same money picture and is invalidated with this
/// slice's views). Foundation may later replace [supabaseClientProvider] with
/// the shared client; the repository + list/detail providers below keep their
/// names.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/data/dues_providers.dart' show invalidateDuesViews;
import '../data/members_repository.dart';
import '../domain/member_money.dart';
import '../models/member.dart';
import '../models/member_detail.dart';
import '../models/payment.dart';

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

/// Search-first member list, each row carrying its resolved money tab so the
/// list can show the pending amount without another round trip.
final membersListProvider = FutureProvider.family<List<MemberWithDues>,
    MemberQuery>(
  (ref, q) async {
    final repo = ref.watch(membersRepositoryProvider);
    final members = await repo.listMembers(gymId: q.gymId, query: q.query);
    if (members.isEmpty) return const <MemberWithDues>[];
    final ids = [for (final m in members) m.id];
    final stretches = await repo.stretchesByMember(ids);
    final payments = await repo.paymentsByMember(ids);
    final today = DateTime.now();
    return [
      for (final m in members)
        MemberWithDues(
          member: m,
          inForce: inForceStretch(
            stretches[m.id] ?? const <Subscription>[],
            today,
          ),
          tab: computeTab(
            stretches: stretches[m.id] ?? const <Subscription>[],
            payments: payments[m.id] ?? const <Payment>[],
            today: today,
          ),
        ),
    ];
  },
  name: 'membersList',
);

/// Detail payload: member + stretches + payments + computed tab.
final memberDetailProvider =
    FutureProvider.family<MemberDetail, String>(
  (ref, memberId) async {
    final repo = ref.watch(membersRepositoryProvider);
    final memberFuture = repo.memberById(memberId);
    final stretchesFuture = repo.stretchesFor(memberId);
    final paymentsFuture = repo.paymentsFor(memberId);
    final member = await memberFuture;
    final stretches = await stretchesFuture;
    final payments = await paymentsFuture;
    final today = DateTime.now();
    return MemberDetail(
      member: member,
      stretches: stretches,
      payments: payments,
      tab: computeTab(
        stretches: stretches,
        payments: payments,
        today: today,
      ),
      inForce: inForceStretch(stretches, today),
      queuedStretch: queuedStretchOf(stretches, today),
      cancelled: isCancelled(stretches, today),
    );
  },
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

/// Plans of one gym for the create/subscribe/change pickers.
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

/// Invalidate every view a member/stretch/payment write can change: the
/// members list, the member's record, and the Home dues feed that shows the
/// same money.
///
/// Callers pass [memberId] when the write touched one member's record; the
/// list and the feed are always refreshed.
void invalidateMemberViews(
  WidgetRef ref, {
  required String gymId,
  String? memberId,
}) {
  ref.invalidate(membersListProvider);
  if (memberId != null) ref.invalidate(memberDetailProvider(memberId));
  invalidateDuesViews(ref);
}
