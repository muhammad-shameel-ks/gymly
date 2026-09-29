/// Member domain models (per GLOSSARY.md + DESIGN.md + ADR-0001).
///
/// - [Member]: paying person at a gym; identity = (gymId, phone).
/// - [Subscription]: one row of `memberships`; current = latest expiry per member.
/// - [DueBucket]: triage position derived from latest expiry vs today.
/// - [MemberWithDues]: member + resolved current subscription for list rows.
///
/// TODO(foundation): re-export spacing/radius/color tokens from
/// `lib/core/theme/app_tokens.dart` when the scaffold lands; the widgets in
/// this slice mirror those values locally until then.
library;

/// Triage bucket for a member (DESIGN.md §2, GLOSSARY.md "Due bucket").
///
/// - [overdue]: expiry < today (or no subscription at all — needs attention).
/// - [dueSoon]: expiry within 7 days (inclusive).
/// - [active]: everything else.
enum DueBucket {
  overdue,
  dueSoon,
  active;

  /// Resolve a bucket from a latest-expiry date (date part only).
  ///
  /// A `null` expiry (member has no subscription rows) resolves to
  /// [overdue] so the member surfaces in triage instead of vanishing.
  static DueBucket fromExpiry(DateTime? expiry, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    if (expiry == null) return DueBucket.overdue;
    final exp = DateTime(expiry.year, expiry.month, expiry.day);
    if (exp.isBefore(day)) return DueBucket.overdue;
    if (exp.difference(day).inDays <= 7) return DueBucket.dueSoon;
    return DueBucket.active;
  }

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

/// One row of the `memberships` table (a Subscription per GLOSSARY.md).
class Subscription {
  const Subscription({
    required this.id,
    required this.gymId,
    required this.memberId,
    this.planId,
    this.planName,
    this.planAmount,
    this.planDurationDays,
    required this.startDate,
    required this.expiryDate,
  });

  final String id;
  final String gymId;
  final String memberId;

  /// Nullable: legacy rows may predate plan assignment.
  final String? planId;

  /// Denormalized at read time via the `plans` embed (may be absent).
  final String? planName;
  final num? planAmount;
  final int? planDurationDays;

  final DateTime startDate;
  final DateTime expiryDate;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    // Supabase embed: `plan:plans(name,amount,duration_days)` or `plans(...)`.
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
      planAmount: plan?['amount'] as num?,
      planDurationDays: (plan?['duration_days'] as num?)?.toInt(),
      startDate: DateTime.parse(json['start_date'] as String),
      expiryDate: DateTime.parse(json['expiry_date'] as String),
    );
  }

  DueBucket bucket({DateTime? today}) =>
      DueBucket.fromExpiry(expiryDate, today: today);

  /// Whole days from [today] to expiry (negative when overdue).
  int daysToExpiry({DateTime? today}) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.difference(day).inDays;
  }
}

/// Member + resolved current subscription (latest expiry) for list rows.
///
/// [current] is `null` when the member has no subscription rows yet.
/// [history] is populated only by the detail path (desc by expiry).
class MemberWithDues {
  const MemberWithDues({
    required this.member,
    required this.current,
    this.history = const [],
  });

  final Member member;
  final Subscription? current;
  final List<Subscription> history;

  DueBucket get bucket =>
      DueBucket.fromExpiry(current?.expiryDate);
}
