# ADR-0002: Start-date corrections

- Status: accepted
- Date: 2026-09-30
- Amended by: [ADR-0003](0003-part-payments-and-plan-cycles.md) — a correction is now a
  single UPDATE of `start_date`; there is no stored expiry to recompute.

> Amended by ADR-0003. The decision below stands (a correction edits the in-force row in
> place), but the row no longer carries an `expiry_date`: correcting `start_date` moves
> the accrual clock and the deadlines with it, and the due bucket is read from money
> owed, not from a stored expiry.

## Context

Owners migrate members who joined before the app did: the real start date is
earlier than the day the record was entered, so `expiry_date` (= entry date +
the plan's duration) is later than what the member was promised. The due date
is wrong, and there is no schema change available to fix it.

ADR-0001 makes renewals append-only: one row per paid period, current
subscription = the row with the latest `expiry_date`. A correction looks like
an append but is not one.

Options:

1. **Append a backdated row** (start = the real start date, expiry = start +
   plan days). Rejected: the current subscription is the latest `expiry_date`,
   so a backdated row expires *before* the row entered on the wrong day and is
   shadowed by it — the due date the owner sees does not move. Making the new
   row win would mean deleting or expiring the wrong row, i.e. editing history
   anyway, with the extra cost of a row nobody will ever read.
2. **UPDATE the active row in place** (`start_date` + recomputed
   `expiry_date`).
3. Keep the wrong date and record the real one elsewhere (the member note).
   Rejected: the due date stays wrong, and the due date is the product.

## Decision

A start-date correction is a distinct operation from a renewal:

- it targets the active subscription row by `id` (the member's latest-expiry
  row) and, in one UPDATE, rewrites `start_date` and
  `expiry_date = start_date + plans.duration_days`;
- it never inserts a row and never touches the member's other rows;
- renewal stays append-only, and this is the only code path besides an
  owner's own data entry that updates a `memberships` row.

Implemented by `MembersRepository.correctStartDate`.
(Renewals: ADR-0001.)

## Rationale

- The owner's promise is the due date; a correction exists to fix it.
- Append-only protects *payment* history (ADR-0001's rationale). A wrong entry
  date is not payment history: it is a clerical error about a period paid for
  elsewhere, and no payment row was ever created for it.
- Corrections happen once per migrated member, so the cost of losing the
  previous date pair is bounded and rare.

## Consequences

- **History for the corrected period is not preserved**: the previous
  start/expiry pair is overwritten, so the app can no longer show what the row
  said before the correction. Accepted — the corrected period is not payment
  history, and no revenue event is lost.
- A corrected row is indistinguishable from a row that was always right; no
  `corrected_at` column is added (no schema change).
- The whole period moves with the start date, so a correction can move a due
  date *earlier* — a member entered late may read as overdue. That is the
  point; the sheet previews the new due date before saving.
- A plan-less legacy row (`plan_id = null`) has no period length to recompute
  from: the UI hides the control, and the repository refuses with a
  `StateError`.
- Renewals after a correction still append from the corrected expiry, so a
  correction made after a renewal only fixes the current period, not the
  earlier ones.
- Corrections live in the members slice: `membersListProvider` and that
  member's `memberDetailProvider` are invalidated, exactly as a renewal from
  the same surface does.
