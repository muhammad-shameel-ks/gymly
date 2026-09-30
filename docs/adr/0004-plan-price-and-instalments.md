# ADR-0004: The plan's price is the debt, instalments pace it

- Status: accepted
- Date: 2026-09-30
- Supersedes: [ADR-0003](0003-part-payments-and-plan-cycles.md), sections *Money accrues per
  day* and *Deadlines drive the bucket* (and its `deadline` term)

## Context

ADR-0003 made money accrue per day: `pending = accrued − paid`, and a member was Overdue only
once a monthly anniversary's accrued target went unmet. On the first day of a ₹3,000 / 90-day
plan that tab reads ₹33 — and a member who pays ₹1,000 at the desk, which is the first month a
gym collects before anyone trains, reads **₹967 advance**. The app tells the owner the member is
in credit while he still owes the plan.

That is not how a gym sells a plan. The member is expected to pay **the price of the plan**;
splits are a negotiation at the desk, not a different price. The owner needs to see ₹3,000 owed
from the day he joins, and the first month collected before he trains.

## Decision

### The plan's price is the tab

While a stretch is in force it owes its own price for **every plan period** (`duration_days`) it
has entered: `owed = price × periods entered` — one on the start day, two from the first day of
the second period. `pending = owed − payments`; a negative value is still an **advance**, but it
now means money past the plan's price rather than past the days elapsed. A mid-period tab is
therefore *larger* than the days used: the rest is the plan the member has committed to.

A stretch that has **ended** settles at the days it ran, never below the instalments already
asked of it and never above the price of the periods it entered:

```text
owed(ended) = min(capacity, max(accrued(ended_on), demanded(ended_on)))
```

Cancelling can therefore release months the member never entered, but it can never un-owe the
month he started.

### Instalments pace it, and the first one is due at signup

```text
instalment = price × 30 ÷ durationDays          one month of the plan
demand(t)  = (calendar months since the start + 1) × instalment, ≤ capacity
```

One month is asked for on the day he joins — **he pays before he trains** — one more at each
monthly anniversary, and the last one lands at the end of his plan. A plan of 30 days or fewer
asks for its whole price in the first instalment. The ladder never asks past the plan's price,
and it freezes on the day a stretch ends.

### The ladder drives the bucket

- **Overdue** — `paid < demand(today)`. What is behind is `demand − paid` (`MemberTab.dueNow`),
  and the instalment day that opened the period is the missed one. A member who has paid nothing
  is Overdue from his first day.
- **Due soon** — not overdue, the next instalment is ≤ 7 days away and `paid < demand(next)`.
- **Active** — everything else, including a member who has paid his plan and is waiting for the
  next period to ask for its first instalment.

The pay sheet pre-fills `dueNow` — the instalment the desk is collecting — while the money line
shows the plan balance behind it, dated to the **end of the plan period he is in** (the day the
balance comes due), not to the next instalment. The card therefore answers two questions at once:
what he owes for this plan and when it must all be in (the amount and date), and whether to chase
him today (the bucket's colour).

## Rationale

- One line has to answer two questions: what the desk collects today (`dueNow`) and what the
  member is worth to the gym (`pending`). Daily accrual answered neither on day one.
- "Pay the first month before you train" is the rule every gym already runs; encoding it removes
  the negotiation from the app's default and makes a brand-new unpaid member show up as owed.
- Daily accrual remains the truthful measure of a *period used*: it is what the cancel preview
  quotes and what an ended stretch settles from. It just is not the tab.
- Splits stay first-class: `pending` is a debt from day one, so a part payment is progress against
  a plan instead of an overpayment against nothing.
- A period's price arrives with the period, so a member who stays another 90 days owes another
  ₹3,000 — and is asked for it a month at a time.

## Consequences

- `MemberTab` exposes `owed`, `accrued`, `paid`, `pending`, `dueNow`, `nextDeadline`,
  `missedDeadline`, `planEnd`, `bucket`, `ringFill`, `payableTo`; `DueRing` fills with `paid / owed`
  and takes null progress when nothing is owed.
- `payableTo` returns the settled **`amount`** (it used to return the accrued sum), so the cancel
  sheet's `Payable to 21 Oct — ₹2,000` and the member's tab can never disagree.
- Paying the plan in full leaves a member Active until the next period's first instalment is
  asked for; from that day he is Overdue again until he pays it.
- `deadline` is renamed **instalment day**: the day the ladder asks — the start date plus monthly
  anniversaries. "Deadline" survives only as an avoided synonym.
- The plan change boundary rule is untouched: a switch still waits out the whole paid period
  (`duration_days`), so instalments and period boundaries stay deliberately different cadences.
- A brand-new member who has not paid is Overdue on the day he joins. That is the point of the
  rule — the Home feed nags for the first month before he trains — and it is pinned in
  `test/features/members/member_money_test.dart`.
