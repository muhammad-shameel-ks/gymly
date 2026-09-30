/// The money model for a member's running tab (DESIGN.md; `docs/voice.md`).
///
/// A `memberships` row is one **stretch**: a snapshot of a plan's price and
/// duration, a start date and (once it ends) an end date. A stretch bills by
/// its **plan period** (`durationDays`, auto-renewing: nothing is written at a
/// boundary) and the tab is what those plans cost, paced by monthly instalments.
///
/// ```text
/// instalment = price × 30 ÷ durationDays                 one month of the plan
/// demand(t)  = (calendar months since start + 1) × instalment, ≤ capacity
/// owed       = price × periods entered                   in force: the plan
/// owed       = max(accrued, demanded) ≤ capacity         ended: what it settled
/// pending    = owed − Σ payments                         negative ⇒ advance
/// ```
///
/// The joint is a gym, not a subscription: a member is expected to pay the
/// **full price of his plan**, and the app says so from the day he joins —
/// ₹3,000 owed on a ₹3,000 plan, not ₹33 of accrued days. Instalments are only
/// the *pace*: one month's worth is demanded the day he joins (`₹3,000 ÷ 3
/// months = ₹1,000`, paid before he trains), then one more at each monthly
/// anniversary, so the last one lands at the end of his plan. Behind the latest
/// demand he is **Overdue**; a member who has paid his plan is Active whether or
/// not the period has run out, and paying the plan in full on day one leaves him
/// owed the *next* period's instalments only when that period starts.
///
/// Leaving early releases the periods he never entered: a stretch that ended
/// settles at the days it ran, never below the instalments already demanded of
/// it, capped at the price of the periods it did enter — so cancelling can never
/// un-owe the month he started.
///
/// Every rupee figure the UI shows comes from [computeTab]: rates keep full
/// precision internally and are rounded to whole ₹ only in the [MemberTab]
/// fields.
///
/// Pure Dart: no Flutter, no Supabase, no `DateTime.now()` — [today] is always
/// a parameter, so every number is reproducible.
library;

import '../models/member.dart';
import '../models/payment.dart';

/// A member's tab on a given day (see [computeTab]).
///
/// [pending] is what he owes; a negative value is an **advance** (money in his
/// favour). [owed], [accrued] and [paid] are whole ₹, rounded for display.
class MemberTab {
  const MemberTab({
    required this.accrualDays,
    required this.accrued,
    required this.owed,
    required this.paid,
    required this.pending,
    required this.dueNow,
    this.nextDeadline,
    this.missedDeadline,
    this.planEnd,
    required this.bucket,
    required this.ringFill,
    this.payableTo,
  });

  /// Days the billing stretches have accrued, summed. A legacy row with no
  /// price snapshot contributes none.
  final int accrualDays;

  /// ₹ accrued so far — what the days the stretches have run are worth at their
  /// plan rate (whole ₹). Mid-period this is *less* than [owed] on purpose: the
  /// rest is the plan he is committed to, not the days he has used.
  final int accrued;

  /// ₹ the plans on his tab cost for the plan periods he has entered (whole ₹):
  /// the plan's price per period while a stretch is in force, and what an ended
  /// stretch settled for.
  final int owed;

  /// ₹ received so far (whole ₹).
  final int paid;

  /// `owed − paid`; negative means an advance.
  final int pending;

  /// `max(0, demanded − paid)` — the instalments the ladder has already asked
  /// for and he has not covered: what has to be collected to make him current.
  final int dueNow;

  /// The next instalment's day: the first monthly anniversary after today.
  final DateTime? nextDeadline;

  /// The deadline he has missed (set only when [bucket] is overdue).
  final DateTime? missedDeadline;

  /// The last day of the plan period the governing stretch is in: the day the
  /// balance on the tab comes due, and the date every money line shows. Null
  /// when nothing bills (no stretch, or a legacy row with no price) and once the
  /// member is cancelled — his tab is closed, the record says `Payable to`.
  final DateTime? planEnd;

  final DueBucket bucket;

  /// `paid / owed`, clamped to `0..1`; `1.0` when nothing is owed.
  final double ringFill;

  /// The day accrual stopped, set when the member is cancelled.
  final DateTime? payableTo;

  /// True when [pending] is negative — money in his favour.
  bool get isAdvance => pending < 0;
}

/// What a member would owe if the tab closed on a chosen day ([payableTo]).
class PayableTo {
  const PayableTo({
    required this.amount,
    required this.days,
    required this.totalDays,
  });

  /// ₹ the tab would settle for on the chosen day (whole ₹).
  final int amount;

  /// Days accrued up to the chosen day.
  final int days;

  /// Days the stretches were sold for, summed.
  final int totalDays;
}

/// The single source of truth for every number the member UI shows.
///
/// [stretches] may be in any order; [payments] are only summed here.
MemberTab computeTab({
  required List<Subscription> stretches,
  required List<Payment> payments,
  required DateTime today,
}) {
  final day = _dateOnly(today);
  final ordered = [...stretches]
    ..sort((a, b) => _dateOnly(a.startDate).compareTo(_dateOnly(b.startDate)));

  var accrualDays = 0;
  var accruedExact = 0.0;
  var owedExact = 0.0;
  for (final s in ordered) {
    if (!_bills(s)) continue; // legacy row: no price snapshot, bills nothing
    final days = _accrualDays(s, day);
    accrualDays += days;
    accruedExact += _rate(s) * days;
    owedExact += _stretchOwed(s, day);
  }

  var paid = 0;
  for (final p in payments) {
    paid += p.amount;
  }

  final accrued = accruedExact.round();
  final owed = owedExact.round();
  final pending = owed - paid;

  // Instalments come from the stretch in force today; when nothing is in
  // force — a cancelled member, or one whose stretches have all ended —
  // they come from the most recently started stretch, so arrears left behind
  // still triage as overdue.
  final governing = _governingStretch(ordered, day);
  DateTime? latestPassed;
  DateTime? next;
  if (governing != null) {
    final deadlines = _deadlines(governing, day);
    latestPassed = deadlines.latestPassed;
    next = deadlines.next;
  }

  final demanded = _demandTotal(ordered, day);
  final dueNow = demanded > paid ? demanded - paid : 0;
  DateTime? missed;
  final DueBucket bucket;
  if (dueNow > 0) {
    // Behind on the instalment the period he is in opened with.
    bucket = DueBucket.overdue;
    missed = latestPassed;
  } else if (next != null &&
      next.difference(day).inDays <= _dueSoonDays &&
      paid < _demandTotal(ordered, next)) {
    bucket = DueBucket.dueSoon;
  } else {
    bucket = DueBucket.active;
  }

  final cancelled = isCancelled(ordered, day);

  return MemberTab(
    accrualDays: accrualDays,
    accrued: accrued,
    owed: owed,
    paid: paid,
    pending: pending,
    dueNow: dueNow,
    nextDeadline: next,
    missedDeadline: missed,
    bucket: bucket,
    ringFill: owed == 0 ? 1.0 : (paid / owed).clamp(0.0, 1.0),
    planEnd: cancelled || governing == null
        ? null
        : cycleWindow(governing, day)?.end,
    payableTo: cancelled ? _latestByStart(ordered)?.endedOn : null,
  );
}

/// What the member would owe if his tab closed on [date] — used by the cancel
/// preview (`Payable to 12 Sep — ₹1,333`, `40 of 90 days`).
PayableTo payableTo({
  required List<Subscription> stretches,
  required DateTime date,
}) {
  final day = _dateOnly(date);
  var amountExact = 0.0;
  var days = 0;
  var totalDays = 0;
  for (final s in stretches) {
    if (!_bills(s)) continue; // legacy row: no price snapshot, bills nothing
    days += _accrualDays(s, day);
    amountExact += _settled(s, day);
    totalDays += s.durationDays ?? 0;
  }
  return PayableTo(
    amount: amountExact.round(),
    days: days,
    totalDays: totalDays,
  );
}

/// The day a plan change takes effect: the first cycle boundary on or after
/// [requestedOn], never earlier than the end of the cycle in force today.
///
/// A **cycle** runs for the plan's own `durationDays` — the period the member
/// has paid for — so the boundaries are `start + k × durationDays` and the
/// switch waits for that paid period to run out. (The *deadlines* inside a
/// cycle are the monthly anniversaries; the two cadences are different on
/// purpose.) A 180-day plan switched in its first month therefore lands six
/// months in, not on the next month's anniversary, or the member would lose the
/// months he has already paid for.
///
/// A stretch that bills nothing (a legacy row with no price snapshot) has no
/// period to run out, so the request's own day is returned.
DateTime planChangeBoundary({
  required Subscription inForce,
  required DateTime requestedOn,
  required DateTime today,
}) {
  final duration = inForce.durationDays;
  final requested = _dateOnly(requestedOn);
  if (!_bills(inForce) || duration == null) return requested;

  final start = _dateOnly(inForce.startDate);
  final day = _dateOnly(today);

  var k = 1;
  while (_addDays(start, k * duration).isBefore(requested)) {
    k++;
  }
  final onOrAfterRequested = _addDays(start, k * duration);

  final window = cycleWindow(inForce, day);
  final endOfCycleToday = _addDays(window!.end, 1);

  return onOrAfterRequested.isAfter(endOfCycleToday)
      ? onOrAfterRequested
      : endOfCycleToday;
}

/// True when nothing is in force today and the most recent stretch ended
/// `cancelled`. [stretches] may be in any order.
bool isCancelled(List<Subscription> stretches, DateTime today) {
  if (stretches.isEmpty) return false;
  final day = _dateOnly(today);
  for (final s in stretches) {
    if (!_dateOnly(s.startDate).isAfter(day) && _covers(s, day)) return false;
  }
  return _latestByStart(stretches)?.endReason == SubscriptionEnd.cancelled;
}

/// Days within which the next deadline counts as "due soon".
const int _dueSoonDays = 7;

/// The plan cycle [s] is in on [day]: the `durationDays`-long window that
/// contains it, counting from the stretch's start, both ends inclusive.
///
/// Auto-renew writes nothing at a boundary, so a stretch has no stored end —
/// this is the period the member record labels instead of inventing one. A
/// stretch that has already ended keeps the window it ended in. `null` for a
/// stretch that bills nothing (a legacy row with no price snapshot).
({DateTime start, DateTime end})? cycleWindow(Subscription s, DateTime day) {
  if (!_bills(s)) return null;
  final duration = s.durationDays!;
  final through = _accrualDays(s, day);
  final index = through <= 1 ? 0 : (through - 1) ~/ duration;
  final start = _addDays(_dateOnly(s.startDate), index * duration);
  return (start: start, end: _addDays(start, duration - 1));
}

// --- stretch arithmetic -----------------------------------------------------

/// True when a stretch has the snapshot it needs to bill: a price and a
/// positive duration. Legacy rows (`price` null) accrue nothing at all.
bool _bills(Subscription s) {
  final duration = s.durationDays;
  return s.price != null && duration != null && duration > 0;
}

/// ₹ per day. Only call for a stretch that [_bills].
double _rate(Subscription s) => s.price! / s.durationDays!;

/// Days [s] has accrued through [through] — both ends inclusive, so the start
/// day is 1 day. Never negative: a future start, or a stretch that ended
/// before it began, accrues 0.
int _accrualDays(Subscription s, DateTime through) {
  final start = _dateOnly(s.startDate);
  final end = _dateOnly(s.endedOn ?? through);
  final last = end.isBefore(through) ? end : through;
  final days = last.difference(start).inDays + 1;
  return days > 0 ? days : 0;
}

/// Everything the stretches have demanded by [date].
int _demandTotal(List<Subscription> stretches, DateTime date) {
  var total = 0;
  for (final s in stretches) {
    if (!_bills(s)) continue;
    total += _stretchDemand(s, date);
  }
  return total;
}

/// What the instalment ladder has demanded of [s] by [through]: one month's
/// worth the day it starts (`₹3,000 ÷ 3 months = ₹1,000` — he pays before he
/// trains), one more at each monthly anniversary, capped at the plan price of
/// the periods the stretch has entered. Nothing is asked before it starts or
/// after its last day, so the demand freezes when it ends.
///
/// Whole ₹: prices and payments are whole ₹, and the full-precision form
/// (`3000 × 30 × 3 ÷ 90` is `3000.0000000000005`) must never turn an
/// exactly-cleared instalment into a shortfall.
int _stretchDemand(Subscription s, DateTime through) {
  final upto = _clampToStretch(s, _dateOnly(through));
  final start = _dateOnly(s.startDate);
  if (upto.isBefore(start)) return 0;

  var months = _monthsBetween(start, upto);
  // The day of the month matters: 12 Oct's instalment is not due on 11 Oct.
  if (_addMonths(start, months).isAfter(upto)) months--;

  final demanded = s.price! * 30 * (months + 1) / s.durationDays!;
  final capacity = _stretchCapacity(s, upto);
  return (demanded < capacity ? demanded : capacity).round();
}

/// The plan price [s] has on the tab by [through]: one price per plan period
/// entered. Zero before it starts.
double _stretchCapacity(Subscription s, DateTime through) =>
    s.price!.toDouble() * _periodsEntered(s, through);

/// Plan periods (each `durationDays` long from the start) that have begun by
/// [through]: 1 on the start day, 2 on the first day of the second period.
int _periodsEntered(Subscription s, DateTime through) {
  final days = _accrualDays(s, through);
  if (days <= 0) return 0;
  return ((days - 1) ~/ s.durationDays!) + 1;
}

/// What [s] is worth on the tab on [day]: in force, the price of the periods it
/// has entered; ended, what it settled for.
double _stretchOwed(Subscription s, DateTime day) {
  final end = s.endedOn == null ? null : _dateOnly(s.endedOn!);
  if (end != null && end.isBefore(_dateOnly(day))) return _settled(s, end);
  return _stretchCapacity(s, day);
}

/// What [s] settles for when it stops on [endDay] — or on its own `endedOn`,
/// when that came first. The days it ran, floored by the instalments already
/// asked of it, capped at the price of the periods it entered.
///
/// The floor is live, not defensive: the ladder counts months at 30 days apiece
/// while the calendar can hand a stretch two 31-day months inside its first
/// anniversary, so late in such a month the days used are worth a rupee or two
/// more than the last instalment asked for. A member who cancels there owes the
/// greater of the two — never less than the month he started.
double _settled(Subscription s, DateTime endDay) {
  final end = _clampToStretch(s, _dateOnly(endDay));
  final accrued = _rate(s) * _accrualDays(s, end);
  final demanded = _stretchDemand(s, end).toDouble();
  final settled = accrued > demanded ? accrued : demanded;
  final capacity = _stretchCapacity(s, end);
  return settled < capacity ? settled : capacity;
}

/// [day] pulled back to the stretch's own last day when that came first.
DateTime _clampToStretch(Subscription s, DateTime day) {
  final end = s.endedOn == null ? null : _dateOnly(s.endedOn!);
  return end != null && end.isBefore(day) ? end : day;
}

/// The stretch whose cycles govern the tab: the one in force today, else the
/// most recently started one.
Subscription? _governingStretch(List<Subscription> stretches, DateTime day) {
  Subscription? inForce;
  for (final s in stretches) {
    if (_dateOnly(s.startDate).isAfter(day)) continue;
    if (!_covers(s, day)) continue;
    if (inForce == null ||
        !_dateOnly(s.startDate).isBefore(_dateOnly(inForce.startDate))) {
      inForce = s;
    }
  }
  return inForce ?? _latestStarted(stretches, day);
}

/// The stretch with the latest start date, whether or not it has begun.
Subscription? _latestByStart(List<Subscription> stretches) {
  Subscription? latest;
  for (final s in stretches) {
    if (latest == null ||
        !_dateOnly(s.startDate).isBefore(_dateOnly(latest.startDate))) {
      latest = s;
    }
  }
  return latest;
}

/// The stretch with the latest start date that has already begun.
Subscription? _latestStarted(List<Subscription> stretches, DateTime day) {
  Subscription? latest;
  for (final s in stretches) {
    if (_dateOnly(s.startDate).isAfter(day)) continue;
    if (latest == null ||
        !_dateOnly(s.startDate).isBefore(_dateOnly(latest.startDate))) {
      latest = s;
    }
  }
  return latest;
}

/// True while [day] falls inside [s]'s run (both ends inclusive).
bool _covers(Subscription s, DateTime day) {
  final start = _dateOnly(s.startDate);
  if (start.isAfter(day)) return false;
  final end = s.endedOn;
  return end == null || !_dateOnly(end).isBefore(day);
}

/// Instalment days of [s]: the day it starts — the first month is due on day
/// one, before he trains — and each monthly anniversary after that. Returns the
/// latest one that has arrived (`<= today`) and the next after today;
/// anniversaries past a stretch's end are dropped, since nothing more is asked
/// of it after it stops.
({DateTime? latestPassed, DateTime? next}) _deadlines(
  Subscription s,
  DateTime today,
) {
  final start = _dateOnly(s.startDate);
  final end = s.endedOn == null ? null : _dateOnly(s.endedOn!);
  DateTime? latestPassed;
  DateTime? next;
  final cap = _monthsBetween(start, today) + 2;
  for (var k = 0; k <= cap; k++) {
    final d = _addMonths(start, k);
    if (end != null && d.isAfter(end)) break;
    if (d.isAfter(today)) {
      next ??= d;
    } else {
      latestPassed = d;
    }
  }
  return (latestPassed: latestPassed, next: next);
}

// --- plain date math (no date package, no DateUtils) ------------------------

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] shifted by whole days, rebuilt from its date parts so a DST shift can
/// never land on the wrong day.
DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Months between two dates by calendar position (not day-of-month precise).
int _monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + (b.month - a.month);

/// [d] shifted by [months] (`months >= 0`), the day clamped to the target
/// month's last day (31 Jan + 1 month ⇒ 28 Feb).
DateTime _addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = _daysInMonth(year, month);
  return DateTime(year, month, d.day <= lastDay ? d.day : lastDay);
}
