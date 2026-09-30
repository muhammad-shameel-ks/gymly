# Changelog

## [1.0.0](https://github.com/muhammad-shameel-ks/gymly/releases/tag/v1.0.0) (2026-09-30)

First release. Gymly is the gym owner's dues desk: **what to collect today, from
whom, and what each member is worth** — for one gym or several, online-only,
no in-app payments.

### Features

- **Plans, members, subscriptions.** Plan = name + ₹ + duration. A member is a
  phone number (one phone, one member per gym). Subscriptions are *stretches*:
  a price snapshot, a start date, and an end date + reason once they stop
  (`cancelled`, `plan_change`). Renewal is automatic — nothing is written when a
  cycle turns over (ADR-0001/0003, superseded in part by ADR-0004).
- **The money model** (ADR-0004): a member owes the **price of the plan period
  he is in** — ₹3,000 owed on a ₹3,000 plan from day one, not ₹33 of accrued
  days. **Instalments pace it**: one month's worth asked for the day he joins
  (he pays before he trains), then one at each monthly anniversary, so the last
  lands at the end of his plan. Behind the latest instalment ⇒ **Overdue** by
  the shortfall; a part payment is progress against the plan rather than an
  unexpected "advance".
- **Part payments.** Every receipt is a `payments` row, editable and deletable
  with confirmation — a typo is not payment history. The Pay sheet pre-fills what
  he owes *now*, never the whole plan.
- **Dues triage.** Home is a feed of Overdue → Due soon → Active, each card
  reading `₹2,500 pending · due 30 Nov` — the balance, dated to the end of the
  plan period he is in — beside the due ring that fills with money paid against
  the plan.
- **Cancellation, reactivation, plan change.** Cancel records the last day he
  came and settles at the days he used, never below the instalments already asked
  for. Reactivate starts a fresh subscription from today (idle days are never
  billed). A plan change is queued at the cycle boundary, written as two rows at
  once, and reversible with Undo.
- **Leads.** Quick-add walk-ins (name + phone), statuses `new → contacted →
  joined / lost`, call/WhatsApp actions, and convert-to-member in one step.
- **Start-date correction.** Migrated members keep their real dates: the in-force
  subscription's start date is rewritten in place, moving the accrual clock and
  the instalment days with it (ADR-0002).
- **Multiple gyms** per owner, with an "All gyms" dues feed.

### Design

- Dark-first premium UI on one accent (indigo), Plus Jakarta Sans bundled, the
  `DueRing` as the single held motif, one sheet chrome (`showAppSheet`) for every
  modal, motion and haptics behind `core/motion/` with a Reduce Motion fallback.
- **Brand mark**: the ring-and-dumbbell logo, drawn from palette tokens in-app
  and rasterized from `assets/branding/` SVGs for Android (adaptive + themed
  monochrome), iOS and web icons.

### Infrastructure

- CI on every pull request: `flutter analyze`, the full test suite, and the
  release-shape split APKs, with the Flutter SDK/pub cache and the Gradle caches
  restored per run.
- Releases: release-please keeps the version and this changelog from conventional
  commits; merging its release PR tags `vX.Y.Z` and attaches the signed per-ABI
  APKs and the Play app bundle to the GitHub Release.
