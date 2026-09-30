/// The member-detail payload: member + every stretch + every payment + the
/// computed tab, resolved once at read time.
///
/// [MemberTab] is computed by `computeTab`; [today] is supplied by the caller,
/// so nothing here reads the clock.
library;

import '../domain/member_money.dart';
import 'member.dart';
import 'payment.dart';

/// Everything the detail screen needs, resolved from one member's rows.
class MemberDetail {
  const MemberDetail({
    required this.member,
    required this.stretches,
    required this.payments,
    required this.tab,
    this.queuedStretch,
    this.inForce,
    required this.cancelled,
  });

  final Member member;

  /// Every stretch, oldest first.
  final List<Subscription> stretches;

  /// Every payment, newest first.
  final List<Payment> payments;

  /// The member's tab as of the day the payload was built.
  final MemberTab tab;

  /// A stretch that starts in the future (a queued plan change), if any.
  final Subscription? queuedStretch;

  /// The stretch covering today, if any.
  final Subscription? inForce;

  /// True when nothing is in force and the last stretch was cancelled.
  final bool cancelled;
}
