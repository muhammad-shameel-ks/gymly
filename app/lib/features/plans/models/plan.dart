/// Plan domain model (per GLOSSARY.md + DESIGN.md).
///
/// A Plan is a membership price template: name + amount (₹) + duration in
/// days. Example: "3 months / ₹3,333". Not tied to any person.
///
/// Pure Dart: no Flutter/Supabase imports so logic stays testable without
/// the foundation scaffold. `intl` is a pure-Dart dependency, so the ₹ label
/// keeps the voice spec's Indian grouping here rather than at every call site.
library;

import 'package:intl/intl.dart';

/// Indian-grouped ₹ formatter (`1,00,000`), built once and reused.
final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

/// One row of the `plans` table.
class Plan {
  const Plan({
    required this.id,
    required this.gymId,
    required this.name,
    required this.amount,
    required this.durationDays,
  });

  final String id;
  final String gymId;
  final String name;

  /// Price in ₹. DB constraint: `amount >= 0`.
  final num amount;

  /// Duration in days. DB constraint: `duration_days > 0`.
  final int durationDays;

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as String,
        gymId: json['gym_id'] as String,
        name: json['name'] as String,
        amount: json['amount'] as num,
        durationDays: (json['duration_days'] as num).toInt(),
      );

  /// Insert/update payload (no `id`; DB generates it).
  Map<String, dynamic> toInsert(String gymId) => {
        'gym_id': gymId,
        'name': name.trim(),
        'amount': amount,
        'duration_days': durationDays,
      };

  Plan copyWith({String? name, num? amount, int? durationDays}) => Plan(
        id: id,
        gymId: gymId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        durationDays: durationDays ?? this.durationDays,
      );

  /// Value equality on [id] so pickers/dropdowns can match selections.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plan && other.id == id && other.gymId == gymId);

  @override
  int get hashCode => Object.hash(id, gymId);

  /// Compact price label, e.g. `₹3,333` or `₹499.5`.
  String get amountLabel => formatPlanAmount(amount);

  /// Human duration, e.g. `3 months`.
  String get durationText => durationLabel(durationDays);

  /// Full picker/row label: `Quarterly · ₹3,333 · 3 months`.
  String get label => '$name · $amountLabel · $durationText';
}

/// The ₹ label for [amount]: Indian grouping, and no decimals on whole
/// amounts (`₹3,333`, not `₹3333.0`; a fractional amount keeps the paise it
/// was stored with, e.g. `₹499.5`).
///
/// Shared by [Plan.amountLabel] and the animated amount in the plans list, so a
/// rolling value never changes shape mid-roll.
String formatPlanAmount(num amount) {
  final whole = amount.remainder(1) == 0;
  return '₹${_inr.format(whole ? amount.toInt() : amount)}';
}

/// Human-friendly duration for a [days] count.
///
/// Prefers whole years, then months (30d), then weeks, then days so that
/// e.g. 90 → `3 months`, 365 → `1 year`, 7 → `1 week`, 10 → `10 days`.
String durationLabel(int days) {
  if (days <= 0) return '$days days';
  if (days % 365 == 0) {
    final n = days ~/ 365;
    return n == 1 ? '1 year' : '$n years';
  }
  if (days % 30 == 0) {
    final n = days ~/ 30;
    return n == 1 ? '1 month' : '$n months';
  }
  if (days % 7 == 0) {
    final n = days ~/ 7;
    return n == 1 ? '1 week' : '$n weeks';
  }
  return days == 1 ? '1 day' : '$days days';
}
