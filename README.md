<h1 align="center">Gymly</h1>

<p align="center">
  <b>The gym owner's dues desk.</b><br>
  What to collect today, from whom, and what every member is worth.<br>
  <sub>One phone. No gateway. No monthly fee for your members.</sub>
</p>

<p align="center">
  <a href="https://github.com/muhammad-shameel-ks/gymly/releases/latest">Download the latest APK</a>
  ·
  <a href="#what-we-offer">What we offer</a>
  ·
  <a href="#how-the-money-works">How the money works</a>
  ·
  <a href="#under-the-hood">Under the hood</a>
</p>

---

Gymly is a mobile app for people who run a gym. It replaces the paper register,
the WhatsApp group of pending dues, and the notebook of "who paid what this
month". It answers three questions every morning:

- **Who do I need to chase today?**
- **How much do they owe, and by when?**
- **Who has already paid ahead?**

It is deliberately **not** a payments app. Cash and UPI change hands at the desk,
exactly as they do today; Gymly records the receipt afterwards. There is no
gateway, no commission, no percentage skimmed from your members' money, and no
transaction to fail when the internet is bad.

---

## Who it's for

| You are… | Gymly gives you |
|---|---|
| A single-gym owner running the front desk yourself | A daily dues list, one-tap payment entry, and a phone tap to reach anyone |
| An owner of two or more branches | Every gym in one account, switchable from the header, with all-gym rollups on the dues feed |
| Tired of monthly renewals typed in by hand | Plans that renew themselves, and instalments that arrive on the right day |
| Handling part payments and cash shortfalls | A running tab per member: what's owed, what's paid, and what's held in advance |
| Taking walk-in enquiries at the counter | A lead list that converts to a member — with their first subscription — in one flow |

Not for (yet): chains with staff logins and role-based permissions, or anyone
needing attendance marking, trainer payroll, or expense accounting.

---

## What we offer

Four tabs, always in the same order, and nothing more than three taps from
anywhere to any action.

### Dues — the morning triage

The home screen is a feed, not a dashboard. It is sorted by who needs you most:

1. **Overdue** — an instalment has come due and it isn't covered
2. **Due soon** — the next one lands within 7 days and isn't covered yet
3. **Active** — everything else, including members who have paid their full plan
   and are simply waiting for the next period to ask

Each card carries the member's name, the plan, the money line
(`₹2,000 pending · due 28 Dec`, or `₹500 advance · due 28 Dec` when someone has
paid ahead), and three one-thumb actions:

| Action | What it does |
|---|---|
| **Pay** | Opens the payment sheet pre-filled with exactly what the member owes right now |
| **Call** | Hands the number to the phone's dialler |
| **WhatsApp** | Opens a chat with the member |

Around the name sits the **DueRing** — a thin ring that fills as the member pays
down the plan he is on, and takes its colour from his bucket. It is the one
glanceable answer to "who is running out". It is drawn, not an image, so it is
correct in light and dark and never lies about the number behind it.

Cancelled members drop out of this feed and are badged in Members instead, so
your call list is never padded with people who have left.

### Members — everyone on the books

A search-first list (name or phone) with a status ring on every row. Tap a
member for the full picture:

- the subscription in force right now, and what its tab stands at
- the history of every subscription stretch and every payment
- part payments, edits and deletions — because a typo is not payment history
- one-tap **Call** and **WhatsApp**

### The member's tab — the part that matters

Gymly's difference is that it computes money instead of storing a number someone
typed. From one plan price and a start date, it knows what the member owes today,
what he owes next month, and what he has paid ahead:

- **Pay** — record a receipt, in full or in part, dated today or any past date.
  The sheet pre-fills the uncovered demand; change it and the tab rebalances.
- **Cancel** — enter the last day he came. Gymly shows you what he owes *before*
  you commit: `Payable to 21 Oct — ₹2,000 · 40 of 90 days`. Leaving releases the
  months he never entered; it can never un-owe the month he started, and any
  advance stays his.
- **Reactivate** — one tap restarts a subscription from today, re-taking the plan
  price (editable) onto the same running tab. The idle days are never billed.
- **Change plan** — pick the new plan and the date; Gymly waits for the current
  paid period to run out and switches on the cycle boundary, so no month is ever
  billed twice and nothing already paid for is stranded. The switch is shown as
  queued, with **Undo** until the boundary arrives.
- **Adjust start date** — imported a paper register? Correct the real start date
  in place and the whole instalment ladder moves with it.

### Leads — walk-ins that don't fall through

Quick-add takes a name, a phone, and an optional note — nothing else, because at
the counter that is all you have. Leads move through **New → Contacted →
Joined** (or **Lost**), and every row has Call and WhatsApp on it.

**Convert to member** carries the name, phone and note across, optionally starts
the first subscription on a plan you choose, records the money received now, and
marks the lead as joined. Walk-in to paying member in one sheet.

### Plans — your price list

Name, amount in ₹, and duration in days (`3 months · ₹3,333`). Create, edit, and
archive from one screen. Assign from a member's detail sheet.

Editing a plan never reprices anyone already on it: each subscription carries its
own price snapshot, so raising next quarter's rate never rewrites last quarter's
history. Archiving a plan that subscriptions still reference is blocked with a
count, not a silent failure.

### Profile — your account and the app itself

- Signed-in email and how many gyms you run
- **Appearance**: System / Dark / Light
- **App updates**: see the installed version, check for a new one, download it
  and hand it to Android's installer — without leaving the app or visiting a
  website
- Log out

### Multiple gyms

Add, rename, or delete branches from the header switcher. Deleting a gym warns
you plainly that its members, plans and dues go with it. On **All gyms**, the
Dues feed aggregates every branch and each card names the gym it came from; the
other tabs ask you to pick one, so a payment is never filed against the wrong
branch.

---

## How the money works

This is the part worth reading, because it is where gym software usually gets
wrong. Gymly has **no stored expiry date anywhere**. Nothing is "renewed" by
hand, and nothing is written when a period turns over. Here is the contract in
full.

### The tab

> The plan's price is the tab.

While a subscription runs, it owes its own price for every plan period it has
entered, and it renews itself:

```
owed    = price × periods entered
pending = owed − payments
```

- `pending` **positive** → he owes you: `₹2,000 pending`
- `pending` **negative** → he has paid ahead: `₹500 advance`

An advance is never silently swallowed. It sits on his tab, survives a
cancellation, and is visible on both the dues feed and his detail screen.

### Instalments — the monthly ladder

Money is asked for a month at a time, because that is the number an owner
actually thinks in:

```
instalment = price × 30 ÷ duration_days
```

A `3 months / ₹3,000` plan is `₹1,000` a month. A plan of 30 days or fewer asks
for its whole price at once.

The **first instalment is due on the day he joins** — he pays before he trains —
and each one after that lands on the monthly anniversary, capped at the price of
the periods the subscription has entered. The last instalment therefore lands
exactly at the end of the plan.

Where a member sits on the dues feed is read from that ladder, never from a
clock:

| Bucket | The test |
|---|---|
| **Overdue** | An instalment has arrived and his payments are behind it |
| **Due soon** | Not overdue, the next instalment is within 7 days, and payments don't cover it |
| **Active** | Everything else — including a member who has paid his plan and is waiting for the next period to ask |

### Plan cycles and plan changes

A **plan cycle** is one paid period: `duration_days` long from the start date. A
90-day plan starting 12 Sep runs to 10 Dec, and the next cycle starts 11 Dec.
Cycles are labels, not rows.

A **plan change** lands on a cycle boundary and writes both rows at once: the
running subscription ends the day before, with reason `plan_change`, and the new
one starts on the boundary day. A six-month plan switched in its first month
lands six months in — never stranding months the member has already paid for.

### Cancellation

Cancellation takes the last day he came (defaulting to today) and stops the
accrual clock there. The subscription settles at the days it actually ran, never
below the instalments already asked of it. The cancel sheet shows you the
`Payable to <date>` and the days used *before* you save, so the conversation at
the desk is never a surprise.

### Verdict

Because the money is derived and not stored, the same member reads identically
everywhere: the dues feed, the member list, and his detail screen cannot
disagree. Correcting a payment, a start date, or a cancellation recomputes
everything downstream, and there is no denormalised number left to go stale.

---

## Design

Dark-first, one accent, ~90% neutral surfaces. Hierarchy comes from size, weight
and position; colour is reserved for meaning.

| Token | Dark | Light | Role |
|---|---|---|---|
| `bg` | `#0B0C10` | `#F6F7FB` | screen |
| `surface` | `#14161C` | `#FFFFFF` | cards, sheets |
| `border` | `#262A33` | `#E3E6EF` | hairlines, ring tracks |
| `text` | `#F2F3F7` | `#101322` | primary text |
| `secondary` | `#9AA1B1` | `#5C6478` | captions, muted icons |
| `accent` | `#6366F1` | `#4F46E5` | primary actions, selected state |
| `accentText` | `#A5B4FC` | `#4338CA` | accent as text, icon or border |
| `error` | `#FF6B6B` | `#C62828` | overdue, destructive, validation |
| `success` | `#34D399` | `#15803D` | active, joined, confirmed |
| `warning` | `#FBBF24` | `#8A5300` | due soon, new lead |

- **Plus Jakarta Sans**, bundled with the app in four weights (SIL OFL 1.1) — no
  network font fetch, no layout shift on first launch.
- **Motion is a token, not a per-screen decision.** Springs for taps, toggles
  and entrances; Material curves as the fallback. Cards rise and fade in a
  ~40 ms stagger, money counters roll to their new value, and the DueRing fills
  as it animates. Reduce Motion is honoured throughout with a cross-fade
  fallback.
- **Haptics carry meaning, consistently**: light on press, a selection tick on
  pickers, success on a saved payment, member or lead, an error buzz on a
  rejected field, and a heavier hit on a destructive commit. Device settings are
  respected, and haptics are never fired on scrolling.
- **One sheet, one chrome.** Every dialog and bottom sheet shares the same
  surface, radius, title, grabber and keyboard handling, and can be dismissed by
  tap, drag, or back.
- **Every list has three honest states** — a skeleton that matches the real
  layout, an empty state that names the next action, and an error that says what
  happened and what to do about it.
- **One back rule.** System back always moves *up*: the top sheet or page first,
  then back to Dues rather than closing the app, and only from Dues does it
  leave. Each tab keeps its own stack, so Dues returns exactly as you left it.
- Tap targets are at least 48 dp, safe areas and edge-to-edge insets are handled
  on every screen, and every money line is ₹ with Indian digit grouping
  (`₹1,00,000`, never `₹100,000`).

---

## Getting the app

**Android** is the shipping platform. Releases are published automatically to
[GitHub Releases](https://github.com/muhammad-shameel-ks/gymly/releases/latest)
with a signed APK per CPU architecture plus an App Bundle. Pick the file that
matches your phone:

| Your phone | Download |
|---|---|
| Almost all modern Android phones | `gymly-v1.1.1-arm64-v8a.apk` |
| Older 32-bit Android | `gymly-v1.1.1-armeabi-v7a.apk` |
| Emulator or Intel Android device | `gymly-v1.1.1-x86_64.apk` |

Open the APK, allow installs from your browser, and Gymly is on the phone. From
then on **Profile → Check for update** does the rest in-app: check, download with
progress, install.

<sub>Current version: **1.1.1** · `com.gymly.gymly` · Android 7.0 (API 24) and up.
iOS is not distributed yet — the app is built for it, but store signing is not
configured. A Play Store listing is not live; the APK above is the install path
today.</sub>

---

## Under the hood

| | |
|---|---|
| **App** | Flutter 3.47.5 · Dart 3.13 · Riverpod 3 · go_router |
| **Backend** | Supabase — PostgreSQL, GoTrue auth, PostgREST, Row-Level Security |
| **Money logic** | Pure Dart, in the app. No stored expiry, no server-side calculation |
| **Design system** | One palette as a `ThemeExtension`, 4-base spacing scale, three type levels, tokenised motion and haptics |
| **Type** | Plus Jakarta Sans (bundled) |
| **Tests** | 8 files, ~2,000 lines, covering the money engine, the updater state machine, and the navigation/sheet contracts |
| **Releases** | Conventional commits → release-please → signed Android artifacts on every merge to `main` |

**Your data is yours, and nobody else's.** Every table in the database is behind
Row-Level Security: an owner can read and write only rows belonging to gyms they
own, and the database enforces it — not the app. Your members' data is not
visible to any other Gymly account, and there is no analytics SDK, no ad
tracker, and no third-party data sharing anywhere in the app.

---

## Not in this version

Stated up front so nothing is a surprise:

- No payment gateway, no in-app charges, no refunds
- No staff logins or roles — v1 is the owner
- No attendance, trainers, or equipment tracking
- No automated SMS/WhatsApp reminders (call and WhatsApp are one tap away)
- No diet or workout plans
- Online-first: reads are cached, but there is no offline write queue, so a
  payment needs a connection to save
- No realtime — the dues feed refreshes when you pull it, not on its own

---

## For developers

```bash
git clone https://github.com/muhammad-shameel-ks/gymly.git
cd gymly/app
flutter pub get
flutter run
```

The app builds against the public Supabase project with a bundled default key, so
there is nothing to configure for a first run. To point it somewhere else:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Bring up your own database with the migrations in `supabase/migrations`:

```bash
supabase db reset
```

| Path | What lives there |
|---|---|
| `app/lib/features/` | One folder per feature: `auth`, `home`, `members`, `leads`, `plans`, `gyms`, `profile`, `updater`, `splash` |
| `app/lib/core/` | Theme, motion, brand signature, shared widgets, Supabase client |
| `app/test/` | Money engine, updater, navigation and sheet contracts |
| `supabase/migrations/` | Schema, constraints, indexes and RLS policies |
| `DESIGN.md` | Product, UX and data contract — the north star |
| `GLOSSARY.md` | Canonical domain vocabulary |
| `docs/adr/` | Why the money model is shaped the way it is |
| `docs/voice.md` | The writing rules every user-facing string follows |
| `docs/ci-cd.md` | Releases, caching, Android signing |
| `AGENTS.md` | How work is done in this repo, for humans and agents |

Contributions are welcome. Branch `feat/` or `fix/` off `main`, keep commits
conventional (`feat:` → minor, `fix:` → patch), and open a PR — CI runs analysis,
the test suite and a real release-mode Android build before it lands. Merging to
`main` publishes a release.

## Documentation

- [DESIGN.md](DESIGN.md) — product, UX and data contract
- [GLOSSARY.md](GLOSSARY.md) — what every term means
- [docs/adr/](docs/adr/) — the money-model decisions, with the reasoning
- [docs/app-updates.md](docs/app-updates.md) — how in-app updates work
- [docs/ci-cd.md](docs/ci-cd.md) — releases, workflows, signing
- [docs/voice.md](docs/voice.md) — the copy rules
- [app/CHANGELOG.md](app/CHANGELOG.md) — release history
