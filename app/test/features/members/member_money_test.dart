import 'package:flutter_test/flutter_test.dart';
import 'package:gymly/features/members/domain/member_money.dart';
import 'package:gymly/features/members/models/member.dart';
import 'package:gymly/features/members/models/payment.dart';

/// `computeTab` is the single source of truth for every number the member UI
/// shows. Every date here is passed in, so the expectations are exact.
void main() {
  Subscription stretch({
    String id = 's1',
    String? planName = 'Monthly',
    int? price,
    int? durationDays,
    required DateTime start,
    DateTime? endedOn,
    SubscriptionEnd? endReason,
  }) =>
      Subscription(
        id: id,
        gymId: 'g1',
        memberId: 'm1',
        planId: 'p1',
        planName: planName,
        price: price,
        durationDays: durationDays,
        startDate: start,
        endedOn: endedOn,
        endReason: endReason,
      );

  Payment payment(int amount, DateTime on, {String id = 'pay'}) => Payment(
        id: id,
        memberId: 'm1',
        amount: amount,
        paidOn: on,
      );

  MemberTab tab(
    List<Subscription> stretches,
    List<Payment> payments,
    DateTime today,
  ) =>
      computeTab(stretches: stretches, payments: payments, today: today);

  group('inclusive day counting', () {
    test('the start day is one day of accrual', () {
      final s = stretch(
        price: 900,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final t = tab([s], const [], DateTime(2026, 9, 12));

      expect(t.accrualDays, 1);
      expect(t.accrued, 10); // 900 / 90 × 1 day — what the day is worth
      expect(t.owed, 900); // …and the plan he is on, which is what he owes
      expect(t.pending, 900);
    });

    test('a stretch that ends the day it starts accrues one day', () {
      final s = stretch(
        price: 500,
        durationDays: 1,
        start: DateTime(2026, 9, 12),
        endedOn: DateTime(2026, 9, 12),
        endReason: SubscriptionEnd.cancelled,
      );
      final t = tab([s], const [], DateTime(2026, 9, 30));

      expect(t.accrualDays, 1);
      expect(t.accrued, 500);
    });

    test('days after the stretch ended stop accruing', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
        endedOn: DateTime(2026, 10, 11),
        endReason: SubscriptionEnd.planChange,
      );
      final t = tab([s], const [], DateTime(2027, 1, 1));

      expect(t.accrualDays, 30); // 12 Sep → 11 Oct inclusive
      expect(t.accrued, 1000);
      expect(t.pending, 1000);
    });
  });

  group('the plan price is the debt', () {
    // A gym is not a subscription: the member is expected to pay the price of
    // his plan, and the app says so from the day he joins. Instalments only pace
    // it — see the instalment-days group.
    Subscription quarterly() => stretch(
          price: 3000,
          durationDays: 90,
          start: DateTime(2026, 9, 12),
        );

    test('₹3,000 on day 90, ₹1,000 paid, owes ₹2,000', () {
      // 12 Sep → 10 Dec inclusive is exactly the 90 days of the plan.
      final t = tab(
        [quarterly()],
        [payment(1000, DateTime(2026, 9, 12))],
        DateTime(2026, 12, 10),
      );

      expect(t.accrualDays, 90);
      expect(t.accrued, 3000);
      expect(t.owed, 3000);
      expect(t.paid, 1000);
      expect(t.pending, 2000);
      expect(t.ringFill, closeTo(1000 / 3000, 1e-9));
      // The first two instalments were missed.
      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 11, 12));
    });

    test('paying month one on day one leaves the plan owed, not an advance',
        () {
      final t = tab(
        [quarterly()],
        [payment(1000, DateTime(2026, 9, 12))],
        DateTime(2026, 9, 12),
      );

      expect(t.accrued, 33); // 3000 / 90 × 1 day
      expect(t.owed, 3000); // the plan's price, not the days used
      expect(t.pending, 2000);
      expect(t.isAdvance, isFalse);
      expect(t.dueNow, 0); // month one is covered
      expect(t.bucket, DueBucket.active);
      expect(t.ringFill, closeTo(1 / 3, 1e-9));
    });

    test('the balance comes due at the end of the plan period he is in', () {
      final first = tab([quarterly()], const [], DateTime(2026, 9, 30));
      expect(first.planEnd, DateTime(2026, 12, 10)); // 12 Sep + 90 days

      final later = tab([quarterly()], const [], DateTime(2026, 12, 20));
      expect(later.planEnd, DateTime(2027, 3, 10)); // the period he is in now
    });

    test('nothing paid on day one is overdue: the first month is due at once',
        () {
      final t = tab([quarterly()], const [], DateTime(2026, 9, 12));

      expect(t.owed, 3000);
      expect(t.pending, 3000);
      expect(t.dueNow, 1000); // one month of a ₹3,000 / 3-month plan
      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 9, 12));
    });
  });

  group('advance', () {
    test('₹3,500 paid against a ₹3,000 plan leaves a ₹500 advance', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final t = tab(
        [s],
        [payment(3500, DateTime(2026, 9, 12))],
        DateTime(2026, 12, 10),
      );

      expect(t.owed, 3000);
      expect(t.paid, 3500);
      expect(t.pending, -500);
      expect(t.isAdvance, isTrue);
      expect(t.ringFill, 1.0);
    });

    test('paying the plan in full settles it until the next period asks', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final planPaid = [payment(3000, DateTime(2026, 9, 12))];

      // The second period's first day: the plan has renewed, so a second price
      // is on the tab, but nothing is behind yet.
      final renewed = tab([s], planPaid, DateTime(2026, 12, 11));
      expect(renewed.owed, 6000);
      expect(renewed.pending, 3000);
      expect(renewed.dueNow, 0);
      expect(renewed.bucket, DueBucket.dueSoon); // its instalment is a day away

      // The day the instalment is asked for, he is behind it.
      final asked = tab([s], planPaid, DateTime(2026, 12, 12));
      expect(asked.dueNow, 1000);
      expect(asked.bucket, DueBucket.overdue);
      expect(asked.missedDeadline, DateTime(2026, 12, 12));
    });
  });

  group('instalment days', () {
    // One month's worth is due the day the member joins — he pays before he
    // trains — and another at each monthly anniversary of that day
    // (`₹3,000 ÷ 3 months = ₹1,000`). Covered up to the latest one, he is
    // current; behind it, he is overdue.
    test('month one paid on 12 Sep; month two is owed on 12 Oct', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final t = tab(
        [s],
        [payment(1000, DateTime(2026, 9, 12))],
        DateTime(2026, 10, 15),
      );

      expect(t.pending, 2000); // month two is on the tab, unpaid
      expect(t.dueNow, 1000);
      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 10, 12));
      expect(t.nextDeadline, DateTime(2026, 11, 12));
    });

    test('two instalments paid, the third asked for on 12 Nov', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final t = tab(
        [s],
        [
          payment(1000, DateTime(2026, 9, 12)),
          payment(1000, DateTime(2026, 10, 12)),
        ],
        DateTime(2026, 11, 15),
      );

      expect(t.paid, 2000);
      expect(t.pending, 1000); // month three
      expect(t.dueNow, 1000);
      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 11, 12));
    });

    test('nothing paid, a month in: two instalments behind', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final t = tab([s], const [], DateTime(2026, 10, 15));

      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 10, 12));
      expect(t.dueNow, 2000);
      expect(t.pending, 3000);
    });

    test('the ladder never asks past the plan price', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      // Day 90, plan paid: nothing is behind, and the instalment for the
      // period that opens on 12 Dec is two days off.
      final t = tab(
        [s],
        [payment(3000, DateTime(2026, 12, 10))],
        DateTime(2026, 12, 10),
      );

      expect(t.owed, 3000);
      expect(t.pending, 0);
      expect(t.dueNow, 0);
      expect(t.bucket, DueBucket.dueSoon);
      expect(t.nextDeadline, DateTime(2026, 12, 12));

      // The period renewed: its price is on the tab and its first instalment
      // is asked for.
      final after = tab(
        [s],
        [payment(3000, DateTime(2026, 12, 10))],
        DateTime(2026, 12, 13),
      );
      expect(after.owed, 6000);
      expect(after.pending, 3000);
      expect(after.dueNow, 1000);
      expect(after.missedDeadline, DateTime(2026, 12, 12));
      expect(after.bucket, DueBucket.overdue);
    });

    test('due soon inside seven days of an instalment, active at eight', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final monthOne = [payment(1000, DateTime(2026, 9, 12))];

      final inSeven = tab([s], monthOne, DateTime(2026, 10, 5));
      expect(inSeven.nextDeadline, DateTime(2026, 10, 12));
      expect(inSeven.bucket, DueBucket.dueSoon);
      expect(inSeven.missedDeadline, isNull);

      final inFour = tab([s], monthOne, DateTime(2026, 10, 8));
      expect(inFour.bucket, DueBucket.dueSoon);

      final inEight = tab([s], monthOne, DateTime(2026, 10, 4));
      expect(inEight.bucket, DueBucket.active);
    });

    test('paying the next instalment ahead of time keeps him current', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final t = tab(
        [s],
        [
          payment(1000, DateTime(2026, 9, 12)),
          payment(1000, DateTime(2026, 10, 8)),
        ],
        DateTime(2026, 10, 8),
      );

      expect(t.dueNow, 0);
      expect(t.pending, 1000);
      expect(t.bucket, DueBucket.active);
      expect(t.nextDeadline, DateTime(2026, 10, 12));
    });

    test('the instalment is owed on its own day, not after it', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      final t = tab(
        [s],
        [payment(1000, DateTime(2026, 9, 12))],
        DateTime(2026, 10, 12),
      );

      expect(t.dueNow, 1000); // month two starts today
      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 10, 12));
      expect(t.nextDeadline, DateTime(2026, 11, 12));
    });
  });

  group('cancel', () {
    // "Last day he came" = 21 Oct: 12 Sep → 21 Oct inclusive is 40 of 90 days,
    // and the two instalments the ladder had already asked for stay owed.
    final cancelled = stretch(
      price: 3000,
      durationDays: 90,
      start: DateTime(2026, 9, 12),
      endedOn: DateTime(2026, 10, 21),
      endReason: SubscriptionEnd.cancelled,
    );

    test('the preview settles at the instalments already asked for', () {
      final preview = payableTo(
        stretches: [cancelled],
        date: DateTime(2026, 10, 21),
      );

      expect(preview.amount, 2000); // 12 Sep and 12 Oct were both asked for
      expect(preview.days, 40);
      expect(preview.totalDays, 90);
    });

    test('settling both instalments on the last day leaves nothing pending',
        () {
      final t = tab(
        [cancelled],
        [payment(2000, DateTime(2026, 10, 21))],
        DateTime(2026, 10, 22),
      );

      expect(t.accrualDays, 40);
      expect(t.accrued, 1333); // the days he came are worth less than he owed
      expect(t.owed, 2000);
      expect(t.pending, 0);
      expect(t.payableTo, DateTime(2026, 10, 21));
      expect(t.planEnd, isNull); // the tab is closed, not running to a date
      expect(t.bucket, DueBucket.active);
      expect(t.nextDeadline, isNull);
    });

    test('the last day he came still counts as in force', () {
      expect(isCancelled([cancelled], DateTime(2026, 10, 21)), isFalse);
      expect(isCancelled([cancelled], DateTime(2026, 10, 22)), isTrue);
    });

    test('arrears stay owed after the cancel', () {
      final t = tab([cancelled], const [], DateTime(2026, 11, 30));

      expect(t.accrualDays, 40); // no accrual after 21 Oct
      expect(t.accrued, 1333);
      expect(t.owed, 2000); // the month he started cannot be un-owed
      expect(t.pending, 2000);
      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 10, 12));
      expect(t.payableTo, DateTime(2026, 10, 21));
    });

    test('an advance survives the cancel', () {
      final t = tab(
        [cancelled],
        [payment(2500, DateTime(2026, 10, 21))],
        DateTime(2026, 11, 30),
      );

      expect(t.pending, -500);
      expect(t.isAdvance, isTrue);
      expect(t.payableTo, DateTime(2026, 10, 21));
    });
  });

  group('isCancelled', () {
    test('false with no stretches at all', () {
      expect(isCancelled(const [], DateTime(2026, 10, 15)), isFalse);
    });

    test('false while a stretch is open', () {
      final open = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      expect(isCancelled([open], DateTime(2026, 10, 15)), isFalse);
    });

    test('false when the last stretch ended with a plan change', () {
      final changed = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
        endedOn: DateTime(2026, 10, 12),
        endReason: SubscriptionEnd.planChange,
      );
      expect(isCancelled([changed], DateTime(2026, 10, 15)), isFalse);
    });

    test('false once a later stretch is running again', () {
      final old = stretch(
        id: 's1',
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 1, 12),
        endedOn: DateTime(2026, 4, 11),
        endReason: SubscriptionEnd.cancelled,
      );
      final reopened = stretch(
        id: 's2',
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 5, 11),
      );
      expect(
        isCancelled([old, reopened], DateTime(2026, 5, 20)),
        isFalse,
      );
    });

    test('true only after the cancelled stretch has run out', () {
      final old = stretch(
        id: 's1',
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 1, 12),
        endedOn: DateTime(2026, 4, 11),
        endReason: SubscriptionEnd.cancelled,
      );
      expect(isCancelled([old], DateTime(2026, 4, 12)), isTrue);
    });
  });

  group('reactivate', () {
    test('idle days between two stretches are never billed', () {
      final before = stretch(
        id: 's1',
        price: 1000,
        durationDays: 30,
        start: DateTime(2026, 1, 12),
        endedOn: DateTime(2026, 2, 10),
        endReason: SubscriptionEnd.cancelled,
      );
      // Reactivated on 12 Mar: 11 Feb → 11 Mar is idle and bills nothing.
      final after = stretch(
        id: 's2',
        price: 1000,
        durationDays: 30,
        start: DateTime(2026, 3, 12),
      );

      final idle = tab([before], const [], DateTime(2026, 2, 20));
      expect(idle.accrualDays, 30);
      expect(idle.owed, 1000);
      expect(isCancelled([before], DateTime(2026, 2, 20)), isTrue);

      final back = tab([before, after], const [], DateTime(2026, 3, 12));
      expect(back.accrualDays, 31); // 30 + exactly 1 day on the new stretch
      expect(back.accrued, 1033); // 1000 + 33.33
      // Both plans are on the tab and the idle month carries neither.
      expect(back.owed, 2000);
      expect(back.pending, 2000);
      expect(back.bucket, DueBucket.overdue); // the new plan's first month
      expect(isCancelled([before, after], DateTime(2026, 3, 12)), isFalse);
    });
  });

  group('three stretches', () {
    test('arrears accumulate across a plan change', () {
      final first = stretch(
        id: 's1',
        price: 1000,
        durationDays: 90,
        start: DateTime(2026, 1, 12),
        endedOn: DateTime(2026, 4, 11),
        endReason: SubscriptionEnd.planChange,
      );
      final second = stretch(
        id: 's2',
        price: 1200,
        durationDays: 90,
        start: DateTime(2026, 4, 12),
        endedOn: DateTime(2026, 7, 11),
        endReason: SubscriptionEnd.planChange,
      );
      final third = stretch(
        id: 's3',
        price: 1500,
        durationDays: 90,
        start: DateTime(2026, 7, 12),
      );

      final t = tab(
        [first, second, third],
        [
          payment(1000, DateTime(2026, 1, 12)),
          payment(500, DateTime(2026, 9, 1)),
        ],
        DateTime(2026, 9, 30),
      );

      expect(t.accrualDays, 262); // 90 + 91 + 81
      expect(t.accrued, 3563); // 1000 + 1213.33 + 1350
      expect(t.owed, 3713); // each plan at its own price: 1000 + 1213.33 + 1500
      expect(t.paid, 1500);
      expect(t.pending, 2213);
      expect(t.dueNow, 2200); // 1000 + 1200 asked for, 1500 of it paid
      // The governing stretch started 12 Jul, so 12 Sep has already passed.
      expect(t.bucket, DueBucket.overdue);
      expect(t.missedDeadline, DateTime(2026, 9, 12));
      expect(t.nextDeadline, DateTime(2026, 10, 12));
    });
  });

  group('planChangeBoundary', () {
    final inForce = stretch(
      price: 3000,
      durationDays: 90,
      start: DateTime(2026, 9, 12),
    );

    test('a request inside the current cycle lands on the paid period end', () {
      expect(
        planChangeBoundary(
          inForce: inForce,
          requestedOn: DateTime(2026, 9, 25),
          today: DateTime(2026, 9, 20),
        ),
        DateTime(2026, 12, 11), // the 90 days he paid for run out on 10 Dec
      );
    });

    test('a late-recorded request cannot rewrite money already accrued', () {
      expect(
        planChangeBoundary(
          inForce: inForce,
          requestedOn: DateTime(2026, 9, 25),
          today: DateTime(2026, 12, 20), // cycle 2 is in force by now
        ),
        DateTime(2027, 3, 11), // the end of the cycle in force today
      );
    });

    test('a request beyond the current cycle keeps its own boundary', () {
      expect(
        planChangeBoundary(
          inForce: inForce,
          requestedOn: DateTime(2027, 1, 1),
          today: DateTime(2026, 9, 20),
        ),
        DateTime(2027, 3, 11),
      );
    });

    test('a request on a boundary day waits for the cycle that starts then',
        () {
      expect(
        planChangeBoundary(
          inForce: inForce,
          requestedOn: DateTime(2026, 12, 11),
          today: DateTime(2026, 12, 11),
        ),
        DateTime(2027, 3, 11),
      );
    });

    test('a six-month plan switches when its six months run out', () {
      // The plan period, not the next monthly anniversary: switching a paid-up
      // 180-day plan after one month must not strand five paid months.
      final halfYear = stretch(
        price: 6000,
        durationDays: 180,
        start: DateTime(2026, 9, 1),
      );
      expect(
        planChangeBoundary(
          inForce: halfYear,
          requestedOn: DateTime(2026, 9, 30),
          today: DateTime(2026, 9, 30),
        ),
        DateTime(2027, 2, 28),
      );
    });

    test('a stretch that bills nothing switches on the requested day', () {
      final legacy = stretch(
        price: null,
        durationDays: null,
        start: DateTime(2026, 9, 1),
      );
      expect(
        planChangeBoundary(
          inForce: legacy,
          requestedOn: DateTime(2026, 10, 5),
          today: DateTime(2026, 9, 30),
        ),
        DateTime(2026, 10, 5),
      );
    });
  });

  group('plan change day boundaries', () {
    // What `changePlan` writes: the old stretch's last day in force is the day
    // before the boundary, and the new stretch opens on the boundary. Every day
    // must then be billed exactly once — a one-day overlap would charge a day of
    // the old plan *and* a day of the new one.
    Subscription closed() => stretch(
          id: 'old',
          price: 3000,
          durationDays: 90,
          start: DateTime(2026, 9, 12),
          endedOn: DateTime(2026, 12, 10),
          endReason: SubscriptionEnd.planChange,
        );
    Subscription opened() => stretch(
          id: 'new',
          price: 6000,
          durationDays: 180,
          start: DateTime(2026, 12, 11),
        );

    test('the boundary day belongs to the new stretch alone', () {
      final t = tab([closed(), opened()], const [], DateTime(2026, 12, 11));

      expect(t.accrualDays, 91); // 90 + 1, never 90 + 2
      expect(t.accrued, 3033); // ₹3,000 + one ₹33.33 day
    });

    test('the old stretch still owns its final day', () {
      final t = tab([closed(), opened()], const [], DateTime(2026, 12, 10));

      expect(t.accrualDays, 90);
      expect(t.accrued, 3000);
    });
  });

  group('legacy rows', () {
    test('a stretch with no price accrues nothing and its ring reads full', () {
      final legacy = stretch(
        planName: null,
        price: null,
        durationDays: null,
        start: DateTime(2026, 1, 12),
      );
      final t = tab(
        [legacy],
        [payment(500, DateTime(2026, 2, 1))],
        DateTime(2026, 9, 30),
      );

      expect(t.accrualDays, 0);
      expect(t.accrued, 0);
      expect(t.owed, 0); // nothing on the tab to owe for
      expect(t.pending, -500);
      expect(t.ringFill, 1.0);
      expect(t.planEnd, isNull);
      expect(t.bucket, DueBucket.active);
    });

    test('a member with no stretches has nothing due', () {
      final t = tab(const [], const [], DateTime(2026, 9, 30));

      expect(t.accrualDays, 0);
      expect(t.accrued, 0);
      expect(t.owed, 0);
      expect(t.paid, 0);
      expect(t.pending, 0);
      expect(t.dueNow, 0);
      expect(t.ringFill, 1.0);
      expect(t.bucket, DueBucket.active);
      expect(t.nextDeadline, isNull);
      expect(t.missedDeadline, isNull);
      expect(t.planEnd, isNull);
      expect(t.payableTo, isNull);
    });

    test('a null price on the row is not backfilled from the plan embed', () {
      final parsed = Subscription.fromJson({
        'id': 's1',
        'gym_id': 'g1',
        'member_id': 'm1',
        'plan_id': 'p1',
        'start_date': '2026-09-12',
        'price': null,
        'duration_days': null,
        'ended_on': null,
        'end_reason': null,
        'plan': {'name': 'Quarterly', 'amount': 3000, 'duration_days': 90},
      });

      expect(parsed.price, isNull);
      expect(parsed.durationDays, isNull);
      expect(parsed.planName, 'Quarterly');
      expect(parsed.isOpen, isTrue);
      expect(parsed.startDate, DateTime(2026, 9, 12));
    });

    test('a closed row parses its end date and reason', () {
      final parsed = Subscription.fromJson({
        'id': 's1',
        'gym_id': 'g1',
        'member_id': 'm1',
        'plan_id': null,
        'start_date': '2026-09-12',
        'price': 3000,
        'duration_days': 90,
        'ended_on': '2026-10-21',
        'end_reason': 'cancelled',
      });

      expect(parsed.endedOn, DateTime(2026, 10, 21));
      expect(parsed.endReason, SubscriptionEnd.cancelled);
      expect(parsed.isOpen, isFalse);
      expect(parsed.planName, isNull);
    });
  });

  group('ring fill', () {
    test('is the paid fraction of the plan, not of the days used', () {
      final s = stretch(
        price: 3000,
        durationDays: 90,
        start: DateTime(2026, 9, 12),
      );
      // One day in, the days he has used are worth ₹33 — the plan is ₹3,000, so
      // ₹1,000 received reads as a third paid rather than a full ring.
      final dayOne = tab(
        [s],
        [payment(1000, DateTime(2026, 9, 12))],
        DateTime(2026, 9, 12),
      );
      expect(dayOne.owed, 3000);
      expect(dayOne.ringFill, closeTo(1 / 3, 1e-9));

      final half = tab(
        [s],
        [payment(500, DateTime(2026, 10, 1))],
        DateTime(2026, 12, 10),
      );
      expect(half.owed, 3000);
      expect(half.ringFill, closeTo(1 / 6, 1e-9));
    });

    test('is clamped to one when the member has paid past his plan', () {
      final s = stretch(
        price: 1000,
        durationDays: 30,
        start: DateTime(2026, 9, 12),
      );
      final t = tab(
        [s],
        [payment(1200, DateTime(2026, 9, 12))],
        DateTime(2026, 9, 13),
      );
      expect(t.owed, 1000);
      expect(t.pending, -200);
      expect(t.ringFill, 1.0);
    });
  });

  group('plan cycle window', () {
    Subscription quarterly() => stretch(
          price: 3000,
          durationDays: 90,
          start: DateTime(2026, 6, 25),
        );

    test('the first cycle runs from the start date for the plan duration', () {
      final w = cycleWindow(quarterly(), DateTime(2026, 7, 24))!;
      expect(w.start, DateTime(2026, 6, 25));
      expect(w.end, DateTime(2026, 9, 22)); // 90 days inclusive
    });

    test('a later cycle is the window the member is in today', () {
      final w = cycleWindow(quarterly(), DateTime(2026, 9, 30))!;
      expect(w.start, DateTime(2026, 9, 23));
      expect(w.end, DateTime(2026, 12, 21));
    });

    test('the day a cycle ends still belongs to that cycle', () {
      final w = cycleWindow(quarterly(), DateTime(2026, 9, 22))!;
      expect(w.start, DateTime(2026, 6, 25));
      expect(w.end, DateTime(2026, 9, 22));
    });

    test('a stretch that ended keeps the window it ended in', () {
      final s = stretch(
        price: 3333,
        durationDays: 90,
        start: DateTime(2026, 5, 2),
        endedOn: DateTime(2026, 7, 20),
        endReason: SubscriptionEnd.cancelled,
      );
      final w = cycleWindow(s, DateTime(2026, 9, 30))!;
      expect(w.start, DateTime(2026, 5, 2));
      expect(w.end, DateTime(2026, 7, 30));
    });

    test('a legacy row with no price snapshot has no window', () {
      final s = stretch(
        price: null,
        durationDays: null,
        start: DateTime(2026, 9, 1),
      );
      expect(cycleWindow(s, DateTime(2026, 9, 30)), isNull);
    });
  });
}
