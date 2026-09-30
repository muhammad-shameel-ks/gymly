# ADR-0001: Append-only renewals

- Status: superseded by [ADR-0003](0003-part-payments-and-plan-cycles.md)
- Date: 2026-09-29
- Superseded by: ADR-0003 — manual per-payment renewals are gone; the plan cycle renews
  by itself and money accrues per day.

> **Superseded by ADR-0003.** Kept for history. The append-per-paid-period rule and the
> `expiry_date` it relied on are no longer how Gymly works: a `memberships` row is now one
> stretch with an optional `ended_on`/`end_reason`, nothing is written at a cycle
> boundary, and money is tracked as a running tab of daily accrual against recorded
> payments. Do not implement this ADR.

## Context

When a member pays for another period, we need to move their due date forward. Two options:

1. **Overwrite** the single `memberships` row (update start/expiry in place).
2. **Append** a new `memberships` row per paid period; the current subscription is the row with the latest `expiry_date` per member.

## Decision

Append-only (option 2). Renewal inserts a new row with `start_date` = old expiry (or today if lapsed) and `expiry_date` = start + plan `duration_days`. Rows are never updated or deleted by renewal.

## Rationale

- Payment history survives: disputes ("I paid for 6 months") are answerable from data, not memory.
- Overwrite destroys the only record of past revenue in a record-only tracker with no payment gateway receipts.
- Cost is negligible: a few rows per member per year; latest-row lookup is covered by `memberships_member_expiry_idx (member_id, expiry_date desc)`.
- Overlapping rows are possible (early renewal) — accepted; UI shows the latest-expiry row only.

## Consequences

- App code must always resolve "current subscription" as latest expiry per member, never assume one row.
- Future revenue reports can aggregate over subscription rows without a separate ledger.
- A start-date **correction** is the one operation that updates a row instead of appending — see ADR-0002.
