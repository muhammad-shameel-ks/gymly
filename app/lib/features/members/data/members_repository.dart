/// Supabase data layer for members, membership stretches and payments.
///
/// A `memberships` row is one *stretch*: the price and duration agreed when it
/// started, a start date, and — once it ends — the day it ended plus why
/// (`cancelled` / `plan_change`). Nothing here stores or recomputes an end
/// date: cycles are deduced by `computeTab` (`domain/member_money.dart`), which
/// accrues money per day over the stretches.
///
/// The stretch in force on a given day is resolved in exactly one place,
/// [inForceStretch]; [queuedStretchOf] finds the future-dated one a queued plan
/// change left behind.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_money.dart';
import '../models/member.dart';
import '../models/payment.dart';

/// Read shape for a `memberships` row: the stretch columns plus the plan-name
/// embed (`null` once the plan is gone; the price/duration snapshots on the row
/// survive that).
const String kSubscriptionCols =
    'id,gym_id,member_id,plan_id,price,duration_days,start_date,ended_on,'
    'end_reason,plan:plans(name)';

/// Read shape for a `payments` row.
const String kPaymentCols = 'id,member_id,amount,paid_on,note';

/// The one place "current stretch" is resolved: the stretch covering [today],
/// or `null` when none is (never joined, or cancelled before today).
///
/// A stretch covers a day when it started on/before it and either has not
/// ended or ended on/after it — both ends inclusive, matching
/// `computeTab`'s day count. When two stretches cover the same day (a plan
/// change closed yesterday's and opened today's), the later start wins.
///
/// [stretches] must be ordered by `start_date` ascending.
Subscription? inForceStretch(List<Subscription> stretches, DateTime today) {
  final day = _dateOnly(today);
  for (final s in stretches.reversed) {
    final start = _dateOnly(s.startDate);
    if (start.isAfter(day)) continue;
    final ended = s.endedOn == null ? null : _dateOnly(s.endedOn!);
    if (ended != null && ended.isBefore(day)) continue;
    return s;
  }
  return null;
}

/// The future-dated stretch a queued plan change left behind, if any.
///
/// [stretches] must be ordered by `start_date` ascending.
Subscription? queuedStretchOf(List<Subscription> stretches, DateTime today) {
  final day = _dateOnly(today);
  for (final s in stretches) {
    if (_dateOnly(s.startDate).isAfter(day)) return s;
  }
  return null;
}

/// Date part only — the granularity every stored date column carries.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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

/// CRUD for members, stretches and payments.
///
/// Throws [DuplicateMemberException] on phone conflicts so callers can
/// surface the friendly exists-message.
class MembersRepository {
  const MembersRepository(this._client);

  final SupabaseClient _client;

  static const _memberCols = 'id,gym_id,name,phone,note';

  /// `yyyy-MM-dd` — the wire format the `date` columns take.
  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// Search-first list scoped to one gym.
  ///
  /// Matches [query] against name/phone (case-insensitive, partial). Dues are
  /// resolved by the caller from [stretchesByMember] + [paymentsByMember].
  Future<List<Member>> listMembers({
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
    return rows
        .map((r) => Member.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
  }

  Future<Member> memberById(String memberId) async {
    final row = await _client
        .from('members')
        .select(_memberCols)
        .eq('id', memberId)
        .single();
    return Member.fromJson(row);
  }

  /// One member's stretches, oldest start first.
  Future<List<Subscription>> stretchesFor(String memberId) async {
    final rows = await _client
        .from('memberships')
        .select(kSubscriptionCols)
        .eq('member_id', memberId)
        .order('start_date', ascending: true) as List<dynamic>;
    return _subscriptions(rows);
  }

  /// One member's payments, newest first.
  Future<List<Payment>> paymentsFor(String memberId) async {
    final rows = await _client
        .from('payments')
        .select(kPaymentCols)
        .eq('member_id', memberId)
        .order('paid_on', ascending: false) as List<dynamic>;
    return _payments(rows);
  }

  /// Stretches of many members in one round trip, grouped by member and
  /// ordered oldest start first inside each group. Members with no rows are
  /// absent from the map.
  Future<Map<String, List<Subscription>>> stretchesByMember(
    List<String> memberIds,
  ) async {
    if (memberIds.isEmpty) return const {};
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

  /// Payments of many members in one round trip, grouped by member and ordered
  /// newest first inside each group. Members with no payments are absent.
  Future<Map<String, List<Payment>>> paymentsByMember(
    List<String> memberIds,
  ) async {
    if (memberIds.isEmpty) return const {};
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

  // ── Member writes ─────────────────────────────────────────────────────────

  /// Create a member; optionally start their first stretch today, with an
  /// optional price override and an optional payment received with it.
  /// Honors `UNIQUE(gym_id, phone)`.
  Future<Member> createMember({
    required String gymId,
    required String name,
    required String phone,
    String? note,
    String? planId,
    int? priceOverride,
    int? firstPayment,
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
          startDate: DateTime.now(),
          priceOverride: priceOverride,
          firstPayment: firstPayment,
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

  // ── Stretch writes ────────────────────────────────────────────────────────

  /// Open a new stretch: the plan's price and duration are copied onto the row
  /// so later plan edits never reprice it.
  ///
  /// [priceOverride] replaces the plan's amount for this member only;
  /// [firstPayment] (₹) records a payment received with the stretch.
  Future<Subscription> startSubscription({
    required String gymId,
    required String memberId,
    required String planId,
    DateTime? startDate,
    int? priceOverride,
    int? firstPayment,
  }) async {
    final plan = await _planSnapshot(planId);
    final start = _dateOnly(startDate ?? DateTime.now());
    final row = await _client
        .from('memberships')
        .insert({
          'gym_id': gymId,
          'member_id': memberId,
          'plan_id': planId,
          'price': priceOverride ?? (plan['amount'] as num).round(),
          'duration_days': (plan['duration_days'] as num).toInt(),
          'start_date': _iso(start),
        })
        .select(kSubscriptionCols)
        .single();
    if (firstPayment != null && firstPayment > 0) {
      await recordPayment(
        gymId: gymId,
        memberId: memberId,
        amount: firstPayment,
        paidOn: start,
      );
    }
    return Subscription.fromJson(row);
  }

  /// Start a new stretch today for a cancelled member, same running tab.
  /// Idle days between the cancel and this are never billed — nothing accrues
  /// while no stretch is in force.
  Future<Subscription> reactivateMembership({
    required String gymId,
    required String memberId,
    required String planId,
    DateTime? today,
    int? priceOverride,
    int? firstPayment,
  }) =>
      startSubscription(
        gymId: gymId,
        memberId: memberId,
        planId: planId,
        startDate: today ?? DateTime.now(),
        priceOverride: priceOverride,
        firstPayment: firstPayment,
      );

  /// Close [stretch] on [lastDayCame] as `cancelled`.
  ///
  /// Accrual stops there; what is owed stays owed and what was overpaid stays
  /// as advance (the tab keeps its payments).
  Future<Subscription> cancelMembership({
    required Subscription stretch,
    required DateTime lastDayCame,
  }) async {
    final day = _dateOnly(lastDayCame);
    final row = await _client
        .from('memberships')
        .update({
          'ended_on': _iso(day),
          'end_reason': SubscriptionEnd.cancelled.dbValue,
        })
        .eq('id', stretch.id)
        .select(kSubscriptionCols)
        .single();
    return Subscription.fromJson(row);
  }

  /// Switch plans at a cycle boundary, written now as two rows.
  ///
  /// [inForce] is closed on **the day before the boundary** — its last day in
  /// force, which is what `ended_on` means everywhere else (a cancel writes the
  /// last day he came, and the domain counts every stretch inclusively). Writing
  /// the boundary itself would leave that one day covered by two stretches and
  /// bill it twice. The new stretch opens on the boundary day from [planId]
  /// (price overridable). The boundary never lands inside the cycle in force
  /// today — see `planChangeBoundary`.
  ///
  /// Returns the inserted (possibly future-dated) stretch.
  Future<Subscription> changePlan({
    required Subscription inForce,
    required String planId,
    required DateTime requestedOn,
    DateTime? today,
    int? priceOverride,
  }) async {
    final now = today ?? DateTime.now();
    // Read the plan first so a bad plan id fails before anything is written.
    final plan = await _planSnapshot(planId);
    final boundary = planChangeBoundary(
      inForce: inForce,
      requestedOn: requestedOn,
      today: now,
    );
    final lastDayInForce = DateTime(
      boundary.year,
      boundary.month,
      boundary.day - 1,
    );
    await _client.from('memberships').update({
      'ended_on': _iso(lastDayInForce),
      'end_reason': SubscriptionEnd.planChange.dbValue,
    }).eq('id', inForce.id);
    final row = await _client
        .from('memberships')
        .insert({
          'gym_id': inForce.gymId,
          'member_id': inForce.memberId,
          'plan_id': planId,
          'price': priceOverride ?? (plan['amount'] as num).round(),
          'duration_days': (plan['duration_days'] as num).toInt(),
          'start_date': _iso(boundary),
        })
        .select(kSubscriptionCols)
        .single();
    return Subscription.fromJson(row);
  }

  /// Undo a queued plan change: drop the inserted stretch and re-open the one
  /// it closed. The inserted stretch goes first so no day is ever covered by
  /// two open stretches.
  Future<void> undoPlanChange({
    required String insertedStretchId,
    required String previousStretchId,
  }) async {
    await _client
        .from('memberships')
        .delete()
        .eq('id', insertedStretchId);
    await _client.from('memberships').update({
      'ended_on': null,
      'end_reason': null,
    }).eq('id', previousStretchId);
  }

  /// Correct the stretch's start date in place.
  ///
  /// One UPDATE of `start_date` (date part) — the single in-place edit allowed
  /// on a stretch. Everything dated moves with it: the accrual clock and the
  /// monthly deadlines both derive from this date at read time.
  Future<Subscription> correctStartDate({
    required String membershipId,
    required DateTime startDate,
  }) async {
    final row = await _client
        .from('memberships')
        .update({'start_date': _iso(_dateOnly(startDate))})
        .eq('id', membershipId)
        .select(kSubscriptionCols)
        .single();
    return Subscription.fromJson(row);
  }

  // ── Payment writes ────────────────────────────────────────────────────────

  /// Record money received from a member. [amount] is ₹ and must be > 0.
  Future<Payment> recordPayment({
    required String gymId,
    required String memberId,
    required int amount,
    required DateTime paidOn,
    String? note,
  }) async {
    final row = await _client
        .from('payments')
        .insert({
          'gym_id': gymId,
          'member_id': memberId,
          'amount': amount,
          'paid_on': _iso(_dateOnly(paidOn)),
          if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
        })
        .select(kPaymentCols)
        .single();
    return Payment.fromJson(row);
  }

  /// Correct a recorded payment (amount, date, note).
  Future<Payment> updatePayment({
    required String id,
    required int amount,
    required DateTime paidOn,
    String? note,
  }) async {
    final row = await _client
        .from('payments')
        .update({
          'amount': amount,
          'paid_on': _iso(_dateOnly(paidOn)),
          'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
        })
        .eq('id', id)
        .select(kPaymentCols)
        .single();
    return Payment.fromJson(row);
  }

  Future<void> deletePayment(String id) async {
    await _client.from('payments').delete().eq('id', id);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// The price + duration the plan prices a new stretch at, right now.
  Future<Map<String, dynamic>> _planSnapshot(String planId) async {
    final row = await _client
        .from('plans')
        .select('amount,duration_days')
        .eq('id', planId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  List<Subscription> _subscriptions(List<dynamic> rows) => rows
      .map((r) => Subscription.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList(growable: false);

  List<Payment> _payments(List<dynamic> rows) => rows
      .map((r) => Payment.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList(growable: false);

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
