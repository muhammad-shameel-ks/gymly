/// One payment made into a member's tab (`public.payments`).
///
/// Payments only ever add money against the running tab; the tab itself is
/// derived in `domain/member_money.dart` (`pending = owed − Σ payments`).
library;

/// One row of the `payments` table.
class Payment {
  const Payment({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.paidOn,
    this.note,
  });

  final String id;
  final String memberId;

  /// ₹ received. DB constraint: `amount > 0`.
  final int amount;

  /// The day the money came in.
  final DateTime paidOn;

  final String? note;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.parse(json['paid_on'] as String);
    return Payment(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      amount: (json['amount'] as num).toInt(),
      paidOn: DateTime(parsed.year, parsed.month, parsed.day),
      note: json['note'] as String?,
    );
  }

  /// Insert payload (no `id`; DB generates it).
  Map<String, dynamic> toInsert(String gymId) => {
        'gym_id': gymId,
        'member_id': memberId,
        'amount': amount,
        'paid_on': _iso(paidOn),
        if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
      };
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
