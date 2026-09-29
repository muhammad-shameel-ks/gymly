/// Supabase data layer for members + subscriptions (memberships).
///
/// Only third-party imports (`supabase_flutter`); no foundation imports yet.
/// The current subscription is always the row with the latest `expiry_date`
/// per member (ADR-0001); renewal appends a row and never updates history.
/// A start-date correction ([correctStartDate]) is the one in-place UPDATE
/// (ADR-0002) — a different operation, not a renewal.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';

/// Thrown when an insert/update violates `UNIQUE(gym_id, phone)` (PG 23505).
///
/// Carries the conflicting [existing] member so the UI can offer an
/// "open instead" link rather than a dead-end error.
class DuplicateMemberException implements Exception {
  const DuplicateMemberException(this.existing);

  final Member existing;

  @override
  String toString() =>
      'Member with this phone already exists: ${existing.name}';
}

/// CRUD + history + append-only renewal for members.
///
/// Throws [DuplicateMemberException] on phone conflicts so callers can
/// surface the friendly exists-message.
class MembersRepository {
  const MembersRepository(this._client);

  final SupabaseClient _client;

  static const _memberCols = 'id,gym_id,name,phone,note';

  /// Embed fragment joining the plan template for subscription rows.
  static const _planEmbed = 'plan:plans(name,amount,duration_days)';

  /// `yyyy-MM-dd` — the wire format the `date` columns take.
  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Search-first list scoped to one gym.
  ///
  /// Matches [query] against name/phone (case-insensitive, partial).
  /// Each row resolves its current subscription (latest expiry) so the
  /// list can render the due-cue ring/dot without extra round trips.
  Future<List<MemberWithDues>> listMembers({
    required String gymId,
    String query = '',
  }) async {
    final q = query.trim();
    var req = _client.from('members').select(_memberCols).eq('gym_id', gymId);
    if (q.isNotEmpty) {
      final like = '%$q%';
      req = req.or('name.ilike.$like,phone.ilike.$like');
    }
    final rows =
        await req.order('name', ascending: true).limit(200) as List<dynamic>;
    final members = rows
        .map((r) => Member.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
    if (members.isEmpty) return const [];

    final ids = members.map((m) => m.id).toList(growable: false);
    final latest = await _latestByMember(ids);
    return members
        .map((m) => MemberWithDues(member: m, current: latest[m.id]))
        .toList(growable: false);
  }

  /// Detail payload: current subscription + full history (desc by expiry).
  Future<MemberWithDues> memberDetail(String memberId) async {
    final mRow = await _client
        .from('members')
        .select(_memberCols)
        .eq('id', memberId)
        .single();
    final member = Member.fromJson(mRow);
    final history = await _history(memberId);
    return MemberWithDues(
      member: member,
      current: history.isEmpty ? null : history.first,
      history: history,
    );
  }

  /// Create a member; optionally assign a plan (inserts the first
  /// subscription starting today). Honors `UNIQUE(gym_id, phone)`.
  Future<Member> createMember({
    required String gymId,
    required String name,
    required String phone,
    String? note,
    String? planId,
  }) async {
    try {
      final row = await _client
          .from('members')
          .insert({
            'gym_id': gymId,
            'name': name.trim(),
            'phone': phone.trim(),
            if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
          })
          .select(_memberCols)
          .single();
      final member = Member.fromJson(row);
      if (planId != null) {
        await startSubscription(
          gymId: gymId,
          memberId: member.id,
          planId: planId,
          from: DateTime.now(),
        );
      }
      return member;
    } on PostgrestException catch (e) {
      if (_isUniqueViolation(e)) {
        throw DuplicateMemberException(
          await _findByPhone(gymId: gymId, phone: phone),
        );
      }
      rethrow;
    }
  }

  /// Edit name/phone/note. Phone clashes surface [DuplicateMemberException].
  Future<Member> updateMember({
    required String id,
    required String name,
    required String phone,
    String? note,
  }) async {
    // Resolve gym first so a 23505 can be mapped to the conflicting row.
    final current = await _client
        .from('members')
        .select('gym_id')
        .eq('id', id)
        .single();
    try {
      final row = await _client
          .from('members')
          .update({
            'name': name.trim(),
            'phone': phone.trim(),
            'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
          })
          .eq('id', id)
          .select(_memberCols)
          .single();
      return Member.fromJson(row);
    } on PostgrestException catch (e) {
      if (_isUniqueViolation(e)) {
        throw DuplicateMemberException(
          await _findByPhone(
            gymId: current['gym_id'] as String,
            phone: phone,
          ),
        );
      }
      rethrow;
    }
  }

  /// Append-only renewal (ADR-0001): insert a new subscription row.
  ///
  /// Start = old expiry when the subscription is still active (early
  /// renewal keeps continuity), else today. Never updates history rows.
  Future<Subscription> renew({
    required String gymId,
    required String memberId,
    required String planId,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final history = await _history(memberId);
    final oldExpiry = history.isEmpty
        ? null
        : DateTime(
            history.first.expiryDate.year,
            history.first.expiryDate.month,
            history.first.expiryDate.day,
          );
    final start = oldExpiry != null && !oldExpiry.isBefore(day)
        ? oldExpiry
        : day;
    return startSubscription(
      gymId: gymId,
      memberId: memberId,
      planId: planId,
      from: start,
    );
  }

  /// Insert the first (or next) subscription for [planId] starting at [from].
  ///
  /// Exposed so create-with-plan and inquiry-convert flows share one path.
  Future<Subscription> startSubscription({
    required String gymId,
    required String memberId,
    required String planId,
    required DateTime from,
  }) async {
    final plan = await _client
        .from('plans')
        .select('duration_days')
        .eq('id', planId)
        .single();
    final days = (plan['duration_days'] as num).toInt();
    final start = DateTime(from.year, from.month, from.day);
    final expiry = start.add(Duration(days: days));
    final row = await _client
        .from('memberships')
        .insert({
          'gym_id': gymId,
          'member_id': memberId,
          'plan_id': planId,
          'start_date': _iso(start),
          'expiry_date': _iso(expiry),
        })
        .select('id,gym_id,member_id,plan_id,start_date,expiry_date,$_planEmbed')
        .single();
    return Subscription.fromJson(row);
  }

  /// Correct the active subscription's dates in place (ADR-0002).
  ///
  /// **Not** a renewal: [renew] appends (ADR-0001), and a backdated append
  /// would be shadowed by the earlier row (current = latest `expiry_date`), so
  /// this rewrites the row identified by [membershipId]: `start_date` =
  /// [startDate] (date part) and `expiry_date` = start + the row's plan
  /// `duration_days`, in one UPDATE. Returns the updated subscription.
  ///
  /// Throws [StateError] when the row carries no plan (nothing to recompute
  /// the period from); a failed read or write propagates the
  /// [PostgrestException] unchanged.
  Future<Subscription> correctStartDate({
    required String membershipId,
    required DateTime startDate,
  }) async {
    final row = await _client
        .from('memberships')
        .select('plan_id')
        .eq('id', membershipId)
        .single();
    final planId = row['plan_id'] as String?;
    if (planId == null) {
      throw StateError('Subscription has no plan; nothing to recompute from.');
    }
    final plan = await _client
        .from('plans')
        .select('duration_days')
        .eq('id', planId)
        .single();
    final days = (plan['duration_days'] as num).toInt();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final expiry = start.add(Duration(days: days));
    final updated = await _client
        .from('memberships')
        .update({
          'start_date': _iso(start),
          'expiry_date': _iso(expiry),
        })
        .eq('id', membershipId)
        .select('id,gym_id,member_id,plan_id,start_date,expiry_date,$_planEmbed')
        .single();
    return Subscription.fromJson(updated);
  }

  /// Latest-expiry subscription per member id (single batched query).
  Future<Map<String, Subscription>> _latestByMember(List<String> ids) async {
    final rows = await _client
        .from('memberships')
        .select('id,gym_id,member_id,plan_id,start_date,expiry_date,$_planEmbed')
        .inFilter('member_id', ids)
        .order('expiry_date', ascending: false) as List<dynamic>;
    final out = <String, Subscription>{};
    for (final r in rows) {
      final s =
          Subscription.fromJson(Map<String, dynamic>.from(r as Map));
      out.putIfAbsent(s.memberId, () => s);
    }
    return out;
  }

  /// Full subscription history, newest expiry first.
  Future<List<Subscription>> _history(String memberId) async {
    final rows = await _client
        .from('memberships')
        .select('id,gym_id,member_id,plan_id,start_date,expiry_date,$_planEmbed')
        .eq('member_id', memberId)
        .order('expiry_date', ascending: false) as List<dynamic>;
    return rows
        .map((r) =>
            Subscription.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
  }

  Future<Member> _findByPhone({
    required String gymId,
    required String phone,
  }) async {
    final row = await _client
        .from('members')
        .select(_memberCols)
        .eq('gym_id', gymId)
        .eq('phone', phone.trim())
        .single();
    return Member.fromJson(row);
  }

  static bool _isUniqueViolation(PostgrestException e) =>
      e.code == '23505' ||
      e.message.contains('duplicate key') ||
      e.message.contains('members_gym_phone');
}
