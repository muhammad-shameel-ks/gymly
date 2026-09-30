# ADR-0003: Part payments and plan cycles

- Status: accepted
- Date: 2026-09-30
- Superseded by: [ADR-0004](0004-plan-price-and-instalments.md) for the money rules — *Money
  accrues per day* and *Deadlines drive the bucket* are replaced there by the plan's price as
  the tab and instalments (asked from the day he joins) as the pace. Everything else here —
  stretches, cycles, cancel, reactivate, plan change, payments as a correctable record — stands.
- Supersedes: [ADR-0001](0001-append-only-renewals.md) — manual per-payment renewals are gone.
- Amends: [ADR-0002](0002-start-date-corrections.md) — a correction no longer recomputes a stored expiry.

## Context

Gymly started as a due-date tracker: one `memberships` row per *paid period*, a **Renew**
button appending a row when the member paid, and a due date read off that row's
`expiry_date`. That model assumes every member pays a whole period up front and that
someone presses Renew the moment money arrives. A real desk does not work that way:

- members pay in parts — ₹1,000 today, the rest on Friday;
- the plan renews by itself whether or not anyone presses a button, so a due date taken
  from a stored expiry goes stale as soon as a cycle turns over;
- members quietly stop coming, and the owner needs to stop the clock on the last day they
  actually came;
- members are migrated from paper, so the dates a record was entered with are often wrong.

ADR-0001's append-per-payment rule cannot express a part payment — half a period is not a
period — and ADR-0002's correction only fixed dates, never money. The schema change that
goes with this ADR (`memberships` snapshot columns plus `ended_on`/`end_reason`, the new
`payments` table, `expiry_date` dropped) is already applied.

## Decision

### One row = one stretch

A `memberships` row is a **subscription**: a snapshot of a plan's price and duration
(`price`, `duration_days`), a `start_date`, and — once it ends — `ended_on` +
`end_reason ∈ ('cancelled', 'plan_change')`. `expiry_date` is dropped. A row stores no
expiry; the in-force stretch is the row with `ended_on is null`, found via
`(member_id, start_date desc)`.

### Money accrues per day

`rate = price / duration_days` (₹ per day; the exact rational value is kept while
accumulating, and rounded to whole ₹ only for display and for `MemberTab`). A stretch
accrues `rate × days`, where `days` counts **both** ends and stops at `ended_on`:
`days_i = max(0, dayCount(start_i, min(today, ended_on_i)))`. Total accrued is the sum
over the member's stretches. `pending = accrued − payments`; a positive value means he
owes it, a negative one is an **advance** in his favour. A stretch with `price = null`
accrues nothing (legacy rows only).

### Nothing is written at a cycle boundary

The plan cycle renews by itself. Cycles exist only to label the display and to generate
deadlines; the money is daily accrual, and no row is inserted or updated when a cycle
turns over. Deadlines are the **monthly anniversaries** of the in-force stretch's start
date (12 Sep ⇒ 12 Oct, 12 Nov, …), and the target at a deadline is what has accrued by the
**day before** it: `target(d) = accrued(d − 1 day)`, capped at the plan's own price. That
one-day offset is what lets the owner's round monthly instalment (`₹3,000 ÷ 3 months =
₹1,000`) clear the first anniversary exactly instead of missing it by a day's accrual.

### Deadlines drive the bucket

- **Overdue** — the latest *passed* deadline's target is not met (`paid < target`); the
  shortfall is `target − paid`.
- **Due soon** — not overdue, the next deadline is ≤ 7 days away, and `paid < target(next)`.
- **Active** — everything else.

### Cancel to the last day

Cancel writes the owner-entered **Last day he came** (defaults to today) to `ended_on`
with `end_reason = 'cancelled'`. Accrual stops there. What he already owes stays owed and
an overpayment stays as an advance. A member is **cancelled** when no stretch is in force
today and the most recent stretch ended with reason `cancelled`. The sheet previews the
accrued amount before saving: `Payable to 12 Sep — ₹1,333` with `40 of 90 days`.

### Reactivate from today

Reactivate appends a **new** stretch starting today, re-taking the plan snapshot (price
overridable at that moment) on the same running tab. Idle days between the last day he
came and today are never billed — that is exactly why reactivation appends a row instead
of reopening the old one.

### Change plan is queued at the boundary, written immediately

A plan change is written as two rows right away: the in-force stretch ends on the **day
before** the boundary (`ended_on`, `end_reason = 'plan_change'`) and a new stretch starts on
the boundary day. The boundary is the first **cycle** boundary on or after the day the owner
entered — and a cycle is the plan's own `duration_days`, so the boundaries are
`start + k × duration_days` — never earlier than the end of the cycle in force today. The
switch therefore waits for the period the member has already paid for to run out; ending the
old stretch *on* the boundary would leave that day covered by two stretches and bill it
twice. Until the boundary arrives the detail screen shows it as the queued switch;
**Undo** deletes the inserted stretch and sets the previous row's `ended_on`/`end_reason`
back to null.

### Payments are a correctable record

`payments` holds one row per receipt: `gym_id`, `member_id`, `amount > 0` (₹), `paid_on`,
optional `note`. Rows are edited and deleted, with confirmation. A mistyped amount is not
payment history — the same reasoning ADR-0002 used for a wrong start date. There is no
payment gateway and no refund flow: the database row is the receipt.

## Rationale

- Daily accrual is the only model that answers a part payment honestly: after ₹1,000 on a
  ₹3,000 plan, `pending` is ₹2,000 of real debt, not "not renewed yet".
- Computing the cycle instead of writing it removes the append-per-payment chore and the
  stale due date; the owner never presses anything for the plan to keep running.
- Monthly deadlines match how members think ("I'll clear it after the 12th") without
  forcing each plan's own duration to decide when money is asked for.
- Cycles and deadlines are deliberately different cadences: money is asked for monthly,
  while a plan change waits out the whole `duration_days` period. Otherwise switching a
  paid-up six-month plan after a month would strand the five months already paid for.
- Cancel-to-the-last-day keeps the number truthful when someone quietly stops coming, and
  reactivating from today keeps the idle gap out of the bill.
- Writing both rows of a plan change at once keeps the data uniform — a stretch has one
  start and one end — while Undo keeps the queued change cheap to reverse.

## Consequences

- ADR-0001 is superseded: there is no Renew button and no append at payment time. Its
  append-only guarantee now means a stretch's `start_date`/`price`/`duration_days` are
  written once, and only `ended_on`/`end_reason` change; ADR-0002's correction is the one
  in-place edit of `start_date`.
- ADR-0002 still holds in spirit but no longer recomputes an expiry: a correction is a
  single UPDATE of the in-force row's `start_date`, and it moves the accrual clock and the
  deadlines with it.
- `MemberTab` exposes `accrualDays, accrued, paid, pending, nextDeadline, missedDeadline,
  bucket, ringFill, payableTo`, all rounded to whole ₹ for display.
- `DueRing` fills with `paid / accrued` (clamped 0..1; full when `accrued == 0`) and keeps
  its colour from the due bucket.
- Reports over time come from `payments` (money received) and the stretches (money owed),
  not from counting appended rows.
- Deleting a late payment can flip a member back to Overdue; the delete confirmation says
  so plainly.
- Renaming or removing the words in the copy list is a breaking change to the interface:
  `pay`, `cancel`, `reactivate`, `change plan`, `last day he came`, `payable to`,
  `pending`, `advance`, `n of total days`. See `docs/voice.md`.
