/// Member domain models (per GLOSSARY.md + DESIGN.md + ADR-0001/0002).
///
/// - [Member]: paying person at a gym; identity = (gymId, phone).
/// - [Subscription]: one row of `memberships` — one *stretch*: a snapshot of a
///   plan's ₹ price and duration running from [Subscription.startDate] until
///   [Subscription.endedOn] (`null` while the stretch is still open).
/// - [SubscriptionEnd]: why a stretch stopped (`cancelled` / `planChange`).
/// - [DueBucket]: triage position; derived by `computeTab` in
///   `domain/member_money.dart`, never from a stored date.
/// - [MemberWithDues]: member + computed tab for list rows.
///
/// Every rupee figure a member owes is derived from the stretches and payments
/// by `computeTab` — see `domain/member_money.dart`.
library;

import '../domain/member_money.dart';

/// Triage bucket for a member (DESIGN.md §2, GLOSSARY.md "Due bucket").
///
/// - [overdue]: the latest passed deadline's target is not met.
/// - [dueSoon]: not overdue, and the next deadline is within 7 days.
/// - [active]: everything else.
enum DueBucket {
  overdue,
  dueSoon,
  active;

  /// Short label for chips/dots.
  String get label => switch (this) {
        DueBucket.overdue => 'Overdue',
        DueBucket.dueSoon => 'Due soon',
        DueBucket.active => 'Active',
      };
}

/// One row of the `members` table.
class Member {
  const Member({
    required this.id,
    required this.gymId,
    required this.name,
    required this.phone,
    this.note,
  });

  final String id;
  final String gymId;
  final String name;
  final String phone;
  final String? note;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        gymId: json['gym_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        note: json['note'] as String?,
      );

  /// Insert/update payload (no `id`; DB generates it).
  Map<String, dynamic> toInsert(String gymId) => {
        'gym_id': gymId,
        'name': name.trim(),
        'phone': phone.trim(),
        if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
      };

  Member copyWith({String? name, String? phone, String? note}) => Member(
        id: id,
        gymId: gymId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        note: note ?? this.note,
      );
}

/// Why a stretch stopped (`memberships.end_reason`).
///
/// A stretch that is still running has a `null` reason.
enum SubscriptionEnd {
  cancelled,
  planChange;

  /// The `memberships.end_reason` value this writes.
  String get dbValue => switch (this) {
        SubscriptionEnd.cancelled => 'cancelled',
        SubscriptionEnd.planChange => 'plan_change',
      };

  /// Parse `memberships.end_reason`; anything unrecognised reads as `null`.
  static SubscriptionEnd? fromDb(String? raw) => switch (raw) {
        'cancelled' => SubscriptionEnd.cancelled,
        'plan_change' => SubscriptionEnd.planChange,
        _ => null,
      };

  /// Short label for the history list.
  String get label => switch (this) {
        SubscriptionEnd.cancelled => 'Cancelled',
        SubscriptionEnd.planChange => 'Changed plan',
      };
}

/// One row of the `memberships` table: one *stretch* of a member's tab.
///
/// [price] and [durationDays] are the plan snapshot taken when the stretch
/// started; both are `null` only on legacy rows, which accrue nothing.
class Subscription {
  const Subscription({
    required this.id,
    required this.gymId,
    required this.memberId,
    this.planId,
    this.planName,
    this.price,
    this.durationDays,
    required this.startDate,
    this.endedOn,
    this.endReason,
  });

  final String id;
  final String gymId;
  final String memberId;

  /// Nullable: legacy rows may predate plan assignment.
  final String? planId;

  /// Denormalized at read time via the `plans` embed (null when the plan is
  /// gone).
  final String? planName;

  /// Snapshot ₹ for one period. `null` on legacy rows → no accrual.
  final int? price;

  /// Snapshot duration in days. `null` on legacy rows → no accrual.
  final int? durationDays;

  final DateTime startDate;

  /// Last day the stretch runs (inclusive). `null` while it is open.
  final DateTime? endedOn;

  /// Why the stretch stopped; `null` while open.
  final SubscriptionEnd? endReason;

  /// True while the stretch has no end date.
  bool get isOpen => endedOn == null;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    // Supabase embed: `plan:plans(name)` or `plans(...)`.
    final embedded = json['plan'] ?? json['plans'];
    final plan = embedded is List
        ? (embedded.isEmpty ? null : embedded.first as Map<String, dynamic>)
        : embedded as Map<String, dynamic>?;
    return Subscription(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      memberId: json['member_id'] as String,
      planId: json['plan_id'] as String?,
      planName: plan?['name'] as String?,
      price: (json['price'] as num?)?.toInt(),
      durationDays: (json['duration_days'] as num?)?.toInt(),
      startDate: DateTime.parse(json['start_date'] as String),
      endedOn: _parseDate(json['ended_on']),
      endReason: SubscriptionEnd.fromDb(json['end_reason'] as String?),
    );
  }
}

/// Member + computed tab for list rows.
///
/// [inForce] is the stretch covering today, when there is one.
class MemberWithDues {
  const MemberWithDues({
    required this.member,
    required this.tab,
    this.inForce,
  });

  final Member member;
  final MemberTab tab;
  final Subscription? inForce;

  DueBucket get bucket => tab.bucket;
}

/// `YYYY-MM-DD` (or full ISO) → local midnight; `null`/blank → `null`.
DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final parsed = DateTime.parse(raw);
  return DateTime(parsed.year, parsed.month, parsed.day);
}
