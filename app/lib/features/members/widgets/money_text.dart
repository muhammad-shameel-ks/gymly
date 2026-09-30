/// The money and date wording for the members slice, in one place
/// (`docs/voice.md`).
///
/// Every screen that shows a running tab, an amount or a short day reads it
/// from here, so Home, the member list and the member record cannot drift into
/// three spellings of `₹2,000 pending` or `12 Oct`.
library;

import 'package:intl/intl.dart';

import '../domain/member_money.dart';

final _inr = NumberFormat.decimalPattern('en_IN');
final _dayMonth = DateFormat('d MMM');

/// `₹2,000` — Indian grouping, no decimals (amounts are whole ₹ everywhere).
String rupees(int amount) => '₹${_inr.format(amount)}';

/// `12 Oct` — the short day every money line and preview uses.
String shortDate(DateTime day) => _dayMonth.format(day);

/// The one money line for a running tab: `₹2,000 pending · due 28 Dec`, or
/// `₹500 advance · due 28 Dec` when he has paid past his plan (voice.md).
///
/// The date is when the balance comes due: the **last day of the plan period he
/// is in**, not the next instalment. The instalment he is behind on is what the
/// bucket colours and what the Pay sheet pre-fills, so the card answers "how
/// much does he owe for this plan, and when must it all be in" while the card's
/// colour answers "chase him now".
///
/// A tab that owes nothing this instant — a member who has paid his plan — drops
/// the money half rather than printing `₹0 pending` beside a date, so he reads
/// `due 28 Dec` alone; with nothing in play either, the line is empty and the
/// caller shows the plan by itself.
String moneyLine(MemberTab tab) {
  final money = switch (tab.pending) {
    > 0 => '${rupees(tab.pending)} pending',
    < 0 => '${rupees(-tab.pending)} advance',
    _ => null,
  };
  final date = tab.planEnd == null ? null : 'due ${shortDate(tab.planEnd!)}';
  return [money, date].whereType<String>().join(' · ');
}
