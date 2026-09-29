/// Supabase data layer for the Home dues feed (DESIGN.md §2/§3).
///
/// Query shape (single round trip, RLS owner-scoped via gyms):
///
/// ```sql
/// -- 1. members of the selected gym(s)
/// select id, gym_id, name, phone, note from members
///   where gym_id = :gym           -- one branch
///      or gym_id in (:g1,:g2,…)   -- All gyms branch
/// -- 2. subscription rows joined to member + plan, ordered so the client
/// --    can resolve current = first row per member (ADR-0001)
/// select id, gym_id, member_id, plan_id, start_date, expiry_date,
///        member:members!inner(id, gym_id, name, phone, note),
///        plan:plans(name, amount, duration_days)
///   from memberships
///   where member_id in (:ids…)
///   order by member_id asc, expiry_date desc
/// ```
///
/// Implemented with postgrest-builder calls (`inFilter` + double `order`);
/// the index `memberships_member_expiry_idx (member_id, expiry_date desc)`
/// covers the ordering. Members with no rows still appear (bucket overdue).
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../members/models/member.dart';

/// One dues card: member + resolved current subscription (latest expiry).
///
/// [current] is null when the member has no subscription rows yet.
class DuesEntry {
  const DuesEntry({
    required this.member,
    required this.current,
    this.gymName,
  });

  final Member member;
  final Subscription? current;

  /// Gym display name for the All-gyms feed; null on single-gym scope.
  final String? gymName;

  DueBucket get bucket => DueBucket.fromExpiry(current?.expiryDate);

  /// Whole days from [today] to expiry; null when no subscription rows.
  int? daysToExpiry({DateTime? today}) => current?.daysToExpiry(today: today);

  /// Due status in the owner's words (`docs/voice.md` rule 4): relative while
  /// the date is close (`due in 3 days`, `expired 12 days ago`), absolute
  /// otherwise (`12 Mar`). `No subscription yet` when the member has no
  /// membership row at all.
  String dueLine({DateTime? today}) {
    final c = current;
    if (c == null) return 'No subscription yet';
    final days = c.daysToExpiry(today: today);
    if (days == 0) return 'due today';
    if (days == 1) return 'due tomorrow';
    if (days == -1) return 'expired yesterday';
    if (days < 0) {
      final ago = -days;
      return ago <= _relativeDays
          ? 'expired $ago days ago'
          : 'expired ${_shortDate(c.expiryDate)}';
    }
    return days <= _relativeDays
        ? 'due in $days days'
        : 'due ${_shortDate(c.expiryDate)}';
  }

  /// `₹amount` with Indian grouping, or `—` when no plan is attached.
  String get amountLabel {
    final amount = current?.planAmount;
    if (amount == null) return '—';
    return rupeeLabel(amount.toDouble(), whole: amount.remainder(1) == 0);
  }
}

/// Past this many days from today a caption names the date instead of
/// counting days (`docs/voice.md` rule 4).
const int _relativeDays = 14;

/// `12 Mar`.
String _shortDate(DateTime d) => DateFormat('d MMM').format(d);

final NumberFormat _inrWhole = NumberFormat.decimalPattern('en_IN')
  ..minimumFractionDigits = 0
  ..maximumFractionDigits = 0;
final NumberFormat _inrPaise = NumberFormat.decimalPattern('en_IN')
  ..minimumFractionDigits = 2
  ..maximumFractionDigits = 2;

/// `₹` label with Indian digit grouping — `₹1,50,000`, or `₹499.50` for a
/// fractional amount.
///
/// [whole] fixes the precision to the *target*, so a rolling label
/// ([AnimatedAmount]) keeps one shape from its first frame to its last.
String rupeeLabel(double amount, {bool whole = true}) => whole
    ? '₹${_inrWhole.format(amount)}'
    : '₹${_inrPaise.format(amount)}';

/// Feed repository: members + current subscriptions join + renew.
class DuesRepository {
  const DuesRepository(this._client);

  final SupabaseClient _client;

  static const _memberCols = 'id,gym_id,name,phone,note';

  /// Embed fragments for the subscription join.
  static const _select =
      'id,gym_id,member_id,plan_id,start_date,expiry_date,'
      'member:members!inner(id,gym_id,name,phone,note),'
      'plan:plans(name,amount,duration_days)';

  /// Members of [gymIds] with their current subscription resolved
  /// client-side from one ordered query (latest expiry per member wins).
  Future<List<DuesEntry>> watchDues({required List<String> gymIds}) async {
    if (gymIds.isEmpty) return const [];
    final members = await _membersOf(gymIds);
    if (members.isEmpty) return const [];
    final byId = {for (final m in members) m.id: m};
    final gymNames = await _gymNames(gymIds);
    final latest = await _latestByMember(byId.keys.toList(growable: false));
    return members
        .map((m) => DuesEntry(
              member: m,
              current: latest[m.id],
              gymName: gymIds.length > 1 ? gymNames[m.gymId] : null,
            ))
        .toList(growable: false);
  }

  /// Single-gym convenience over [watchDues].
  Future<List<DuesEntry>> watchDuesForGym(String gymId) =>
      watchDues(gymIds: [gymId]);

  /// Append-only renewal (ADR-0001): insert a new subscription row.
  ///
  /// [planId]/[durationDays] come from the plan picked in the Renew sheet.
  /// Start = old expiry when still active, else today; expiry = start +
  /// [durationDays]. Never updates history rows.
  Future<Subscription> renew({
    required String gymId,
    required String memberId,
    required String planId,
    required int durationDays,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final rows = await _client
        .from('memberships')
        .select('expiry_date')
        .eq('member_id', memberId)
        .order('expiry_date', ascending: false)
        .limit(1) as List<dynamic>;
    DateTime? oldExpiry;
    if (rows.isNotEmpty) {
      oldExpiry = DateTime.parse(
        (rows.first as Map)['expiry_date'] as String,
      );
    }
    final oldDay = oldExpiry == null
        ? null
        : DateTime(oldExpiry.year, oldExpiry.month, oldExpiry.day);
    final start =
        (oldDay != null && !oldDay.isBefore(day)) ? oldDay : day;
    final expiry = start.add(Duration(days: durationDays));
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final row = await _client
        .from('memberships')
        .insert({
          'gym_id': gymId,
          'member_id': memberId,
          'plan_id': planId,
          'start_date': iso(start),
          'expiry_date': iso(expiry),
        })
        .select(_select)
        .single();
    return Subscription.fromJson(Map<String, dynamic>.from(row));
  }

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

  /// Latest-expiry subscription per member id.
  ///
  /// Rows arrive ordered (member_id asc, expiry desc) so the first row
  /// per member is its current subscription; a Map putIfAbsent keeps it.
  Future<Map<String, Subscription>> _latestByMember(
    List<String> ids,
  ) async {
    final rows = await _client
        .from('memberships')
        .select(_select)
        .inFilter('member_id', ids)
        .order('member_id', ascending: true)
        .order('expiry_date', ascending: false) as List<dynamic>;
    final out = <String, Subscription>{};
    for (final r in rows) {
      final json = Map<String, dynamic>.from(r as Map);
      final embedded = json['member'];
      final hasMember = embedded is Map<String, dynamic> ||
          (embedded is List && embedded.isNotEmpty);
      if (!hasMember) continue;
      final s = Subscription.fromJson(json);
      out.putIfAbsent(s.memberId, () => s);
    }
    return out;
  }
}
