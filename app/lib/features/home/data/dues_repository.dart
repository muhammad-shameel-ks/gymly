/// Supabase data layer for the Home dues feed.
///
/// The feed is derived, not stored: one row per member whose tab has money
/// outstanding or a deadline in play, built from their stretches + payments via
/// `computeTab` (`members/domain/member_money.dart`). Nothing is written at a
/// cycle boundary — money accrues per day.
///
/// Query shape (two batched reads, RLS owner-scoped via gyms):
///
/// ```sql
/// -- 1. members of the selected gym(s)
/// select id, gym_id, name, phone, note from members
///   where gym_id = :gym           -- one branch
///      or gym_id in (:g1,:g2,…)   -- All gyms branch
/// -- 2. stretch + payment rows of those members, grouped client-side
/// select id, gym_id, member_id, plan_id, price, duration_days, start_date,
///        ended_on, end_reason, plan:plans(name)
///   from memberships where member_id in (:ids…) order by start_date asc
/// select id, member_id, amount, paid_on, note
///   from payments where member_id in (:ids…) order by paid_on desc
/// ```
///
/// Cancelled members never reach the feed (their arrears live on their record);
/// they still appear in the members list.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../members/data/members_repository.dart';
import '../../members/domain/member_money.dart';
import '../../members/models/member.dart';
import '../../members/models/payment.dart';

/// One dues card: member + computed money tab + the stretch in force.
class DuesEntry {
  const DuesEntry({
    required this.member,
    required this.tab,
    this.inForce,
    this.gymName,
  });

  final Member member;
  final MemberTab tab;

  /// The stretch covering today, `null` when the member has none in force.
  final Subscription? inForce;

  /// Gym display name for the All-gyms feed; null on single-gym scope.
  final String? gymName;

  DueBucket get bucket => tab.bucket;

  /// `pending` when he owes, negative when the balance is an advance.
  int get pending => tab.pending;
  DateTime? get nextDeadline => tab.nextDeadline;
  DateTime? get missedDeadline => tab.missedDeadline;

  /// Name of the plan in force, `null` when there is none (or it is gone).
  String? get planName => inForce?.planName;

}

/// Feed repository: members + their stretches + payments, shaped into cards.
class DuesRepository {
  const DuesRepository(this._client);

  final SupabaseClient _client;

  static const _memberCols = 'id,gym_id,name,phone,note';

  /// Members of [gymIds] with pending money or a deadline in play.
  ///
  /// Sort happens in the provider (Overdue → Due soon → Active).
  Future<List<DuesEntry>> watchDues({required List<String> gymIds}) async {
    if (gymIds.isEmpty) return const [];
    final members = await _membersOf(gymIds);
    if (members.isEmpty) return const [];
    final ids = [for (final m in members) m.id];
    final stretchesFuture = _stretchesOf(ids);
    final paymentsFuture = _paymentsOf(ids);
    final gymNames = await _gymNames(gymIds);
    final stretches = await stretchesFuture;
    final payments = await paymentsFuture;
    final allGyms = gymIds.length > 1;
    final today = DateTime.now();

    final out = <DuesEntry>[];
    for (final m in members) {
      final memberStretches = stretches[m.id] ?? const <Subscription>[];
      // Cancelled members leave the feed; their arrears stay on their record.
      if (isCancelled(memberStretches, today)) continue;
      final tab = computeTab(
        stretches: memberStretches,
        payments: payments[m.id] ?? const <Payment>[],
        today: today,
      );
      final deadlineInPlay =
          tab.nextDeadline != null || tab.missedDeadline != null;
      if (tab.pending <= 0 && !deadlineInPlay) continue;
      out.add(DuesEntry(
        member: m,
        tab: tab,
        inForce: inForceStretch(memberStretches, today),
        gymName: allGyms ? gymNames[m.gymId] : null,
      ));
    }
    return out;
  }

  /// Single-gym convenience over [watchDues].
  Future<List<DuesEntry>> watchDuesForGym(String gymId) =>
      watchDues(gymIds: [gymId]);

  Future<List<Member>> _membersOf(List<String> gymIds) async {
    final rows = await _client
        .from('members')
        .select(_memberCols)
        .inFilter('gym_id', gymIds)
        .order('name', ascending: true)
        .limit(500) as List<dynamic>;
    return rows
        .map((r) => Member.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
  }

  Future<Map<String, String>> _gymNames(List<String> gymIds) async {
    final rows = await _client
        .from('gyms')
        .select('id,name')
        .inFilter('id', gymIds) as List<dynamic>;
    final out = <String, String>{};
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      out[m['id'].toString()] = m['name'].toString();
    }
    return out;
  }

  /// Stretches of many members, grouped by member, oldest start first.
  Future<Map<String, List<Subscription>>> _stretchesOf(
    List<String> memberIds,
  ) async {
    final rows = await _client
        .from('memberships')
        .select(kSubscriptionCols)
        .inFilter('member_id', memberIds)
        .order('start_date', ascending: true) as List<dynamic>;
    final out = <String, List<Subscription>>{};
    for (final r in rows) {
      final s = Subscription.fromJson(Map<String, dynamic>.from(r as Map));
      (out[s.memberId] ??= <Subscription>[]).add(s);
    }
    return out;
  }

  /// Payments of many members, grouped by member, newest first.
  Future<Map<String, List<Payment>>> _paymentsOf(
    List<String> memberIds,
  ) async {
    final rows = await _client
        .from('payments')
        .select(kPaymentCols)
        .inFilter('member_id', memberIds)
        .order('paid_on', ascending: false) as List<dynamic>;
    final out = <String, List<Payment>>{};
    for (final r in rows) {
      final p = Payment.fromJson(Map<String, dynamic>.from(r as Map));
      (out[p.memberId] ??= <Payment>[]).add(p);
    }
    return out;
  }
}
