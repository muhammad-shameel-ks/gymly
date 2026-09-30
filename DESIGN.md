# DESIGN.md — Gymly (v1)

Product + UX + data contract for the gym-owner mobile app. Stack: **Flutter + Supabase**.
Domain language per `GLOSSARY.md`; money model per
`docs/adr/0004-plan-price-and-instalments.md` (stretches, cycles, cancel, reactivate, plan change
per ADR-0003).

## 1. Scope (v1)

**In:** owner auth, multiple gyms per owner, plans, members, subscriptions (stretches)
with part payments and due triage, cancel / reactivate / change plan, payment records
kept at the desk (record, correct, delete), minimal inquiries with convert-to-member,
dues dashboard.

**Out:** payment gateways, refunds, staff logins, attendance, trainers, expenses,
auto-reminders, diet/workout plans, offline write-queue, realtime. The app **records**
money; it never moves it. Cash and UPI change hands at the desk, and the owner enters the
receipt afterwards.

## 2. Data model (Supabase `public`, verified 2026-09-30)

| Table | Key columns | Rule |
|---|---|---|
| `gyms` | `id`, `owner_id → auth.users`, `name` | One row per location. |
| `plans` | `gym_id`, `name`, `amount ≥ 0` (₹), `duration_days > 0` | Price × duration template. |
| `members` | `gym_id`, `name`, `phone`, `note?` | `UNIQUE(gym_id, phone)` — one phone = one member per gym. |
| `memberships` | `gym_id`, `member_id`, `plan_id?`, `start_date`, `price?`, `duration_days?`, `ended_on?`, `end_reason?` | One row = one **stretch**: a plan-price snapshot + start date, plus an end date and reason (`cancelled` / `plan_change`) once it ends. No stored expiry. In force = the row with `ended_on is null`; indexed `(member_id, start_date desc)`. Constraints: `price`/`duration_days` both null or both set, `price ≥ 0`, `duration_days > 0`; `ended_on`/`end_reason` both null or both set, `ended_on ≥ start_date`. |
| `payments` | `gym_id`, `member_id`, `amount > 0` (₹), `paid_on`, `note?` | One row per receipt, recorded at the desk; correctable (edit/delete with confirmation). Indexed `(member_id, paid_on desc)` and `(gym_id, member_id)`. |
| `inquiries` | `gym_id`, `name`, `phone`, `note?`, `status new/contacted/joined/lost`, `member_id?` | Quick-add only: name + phone required, note optional. No follow-up/source fields. `member_id` set when converted (`on delete set null`). |

**RLS (owner-only):** `gyms_owner_all` (`owner_id = auth.uid()`); `memberships_owner_all`
and `payments_owner_all` (and every other table) owner-via-gym
`EXISTS (gyms … owner_id = auth.uid())`. No staff roles in v1.

**Core rules:**

- **The plan's price is the tab.** While a stretch is in force it owes its own price for every
  **plan period** it has entered (`duration_days` each, auto-renewing — nothing is written at a
  boundary): `owed = price × periods entered`. `pending = owed − payments` — positive = he owes
  it, negative = **advance** (money past the plan's price). An ended stretch settles at the days
  it ran, never below the instalments already asked of it. `rate = price / duration_days` and
  `accrued = rate × days` (both ends inclusive, stopping at `ended_on`) still measure the days
  used — they are what the cancel preview quotes — and a stretch with `price = null` bills
  nothing.
- **Instalments.** `instalment = price × 30 ÷ duration_days`, asked for on the start date — the
  first month is due the day he joins, he pays before he trains — and at each monthly anniversary
  after it, capped at the price of the periods entered, so the last one lands at the end of the
  plan. **Overdue** when `paid < demanded`; **Due soon** when not overdue, the next instalment is
  ≤ 7 days away and `paid < demanded(next)`; **Active** otherwise, including a member who has paid
  his plan and is waiting for the next period to ask. The Pay sheet pre-fills the uncovered demand
  (`dueNow`).
- **Cancel** writes `Last day he came` (defaults to today) to `ended_on`, reason
  `cancelled`; accrual stops there and the stretch settles at the days it ran, never below the
  instalments already asked of it — leaving releases the months he never entered, never the
  month he started. What he already owes stays owed, an advance stays. A
  member is **cancelled** when no stretch is in force today and the latest ended
  `cancelled`.
- **Reactivate** appends a new stretch from today (snapshot re-taken, price overridable);
  idle days are never billed, and the new stretch's first instalment is due at once.
- **Change plan** writes two rows immediately — the in-force stretch ends on the day
  *before* the boundary with reason `plan_change`, and a new stretch starts on the boundary.
  The boundary is the first cycle boundary (a `duration_days` period, so `start + k ×
  duration_days`) on/after the entered date, never earlier than the end of the cycle in
  force today, so the switch waits for the paid period to run out and no day is billed
  twice. Shown as the queued switch; **Undo** deletes the new row and clears the old row's
  end.
- **Start-date correction** (ADR-0002) is a single `start_date` UPDATE of the in-force
  stretch; it moves the accrual clock and the instalment days with it.
- Convert inquiry = create `member` (+ first `membership`) and set inquiry `joined`.

## 3. Information architecture

Four bottom tabs: **Home (Dues) · Members · Leads · Plans**. ≤ 3 taps to any action.

- **Header:** gym switcher (drops down gym list + "All gyms"). Home aggregates all gyms
  when "All gyms" is selected; other tabs filter to one gym (prompt to pick if "All").
- **Home:** dues triage feed — Overdue, then Due soon, then Active; cancelled members are
  out of it. Each card: member name, plan, money line `₹2,000 pending · due 28 Dec`
  (`₹500 advance · due 28 Dec` when paid ahead) — the balance, dated to the end of the plan
  period he is in — the `DueRing`; one-thumb actions
  **Pay** (pre-filling what he owes now) / **Call** / **WhatsApp**.
- **Members:** search-first list (name/phone), due-status ring/dot cue, `Cancelled` badge;
  detail shows the in-force stretch, the history of stretches and payments, and
  **Pay / Cancel / Reactivate / Change plan** (plus the queued change with Undo).
- **Leads:** quick-add (name, phone, note) + list by status; row actions Call / WhatsApp /
  Convert to member.
- **Plans:** name + ₹ + duration chips; create/edit/archive; assign from member detail.

## 4. Visual system (per attached Mobile UI/UX Rules spec)

Dark-first premium. One accent, ~90% neutral surfaces; hierarchy via size/weight/position.
Colour lives in **`AppPalette`** (`lib/core/theme/app_palette.dart`) — a `ThemeExtension`
registered in both themes, read as `context.palette`. Never hardcode a hex outside it.

```dart
// spacing (4-base) / radius (one per role) / type (3 levels, metrics only)
space: xs 4, sm 8, md 16, lg 24, xl 32   // screen padding 20 (AppSpace.screen)
radius: card 16, sheet 24, pill 999
title 26/700/32 · subtitle 19/600/26 · body 16/400/24 (≥14, 1.5x) · caption 13/400/18
AppType carries NO colour — always .copyWith(color: context.palette.…)
```

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#0B0C10` | `#F6F7FB` | screen background |
| `surface` | `#14161C` | `#FFFFFF` | cards, sheets |
| `border` | `#262A33` | `#E3E6EF` | hairlines, dividers |
| `text` | `#F2F3F7` | `#101322` | primary text |
| `secondary` | `#9AA1B1` | `#5C6478` | secondary text, inactive icons |
| `accent` | `#6366F1` | `#4F46E5` | **fill only**: primary actions, selected state |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | label/icon on `accent` |
| `accentText` | `#A5B4FC` | `#4338CA` | accent **as** text/icon/border |
| `error` | `#FF6B6B` | `#C62828` | destructive, validation |
| `success` | `#34D399` | `#15803D` | confirmation |
| `warning` | `#FBBF24` | `#8A5300` | caution |

- Indigo brand replaces the original volt accent: volt could not meet 4.5:1 as text on
  light surfaces, so one fill-only accent + a mode-deepened `accentText` was necessary.
- `AppTheme` supplies component defaults (buttons, inputs, sheets, dialogs, snackbars,
  segmented controls, FAB) — screens set only what is genuinely local.
- **Signature element:** `DueRing` (`lib/core/signature/due_ring.dart`) — a thin ring that fills
  with money paid against the plan he is on (`paid / owed`, clamped 0..1, full when nothing is
  owed) and takes its colour from the due bucket. It is the app's one held visual motif and it
  earns its place by making "who is running out" legible at a glance. Never place it where there
  is nothing owed to encode.
- **Brand mark:** the same ring-and-dumbbell drawing as the launcher icon, painted
  (`lib/core/signature/gymly_mark.dart`) from palette tokens so it is correct in both themes, and
  shown as `GymlyBrandLockup` — mark above the two-tone `Gymly` wordmark — wherever the app
  introduces itself (launch surface, auth hero), never on a working screen. Icon sources are the
  SVGs in `assets/branding/`; the OS icon sets are rasterized from them with
  `dart run flutter_launcher_icons`, so a generated icon is never hand-edited.
- **Voice:** `docs/voice.md` is binding for every user-facing string (empty states name the next
  action, errors say what happened → what to do → the control, confirmations are past tense + fact).
- Font: **Plus Jakarta Sans** (`assets/fonts/`, weights 400/500/600/700, SIL OFL 1.1 —
  license bundled as an asset). One family, no network font fetch. `AppType.family`
  is the single reference; `AppTheme` applies it to both themes.
- TikTok/IG steal, management-app restraint: Home is a vertical triage feed (swipeable
  due cards, full-bleed rows, snap triage); Members/Leads use IG-style search + status
  rings for overdue/due-soon; no story auto-play, no algorithmic feed chrome.
- Tap targets ≥ 44×44pt / 48×48dp, 8px gaps; safe-area + Android edge-to-edge insets on
  every screen; 16px+ horizontal padding; contrast ≥ 4.5:1.
- Every list ships loading (skeleton matching layout) + empty (guided next action) +
  error (what → what-to-do → retry) states. Those states are centred while they fit and
  scroll (`ScrollableStateBody`) when their slot is shorter than the content — at max text
  scale too — so copy and CTA are never clipped. Online-first v1: cached reads, no write queue.
- **No realtime**: `public` is not in the `supabase_realtime` publication. Reads are
  futures (`select()`), refreshed with `ref.invalidate` after writes.

### Sheets (one chrome)

Every bottom sheet goes through `showAppSheet` + `AppSheet`
(`lib/core/widgets/app_sheet.dart`). No screen calls `showModalBottomSheet`
directly: the route flags below are the fix for a class of bugs, so they live in
one place.

- **Root navigator, always** (`useRootNavigator: true`). Tab bodies live in
  `Scaffold.body` behind a branch `Navigator`, so a sheet pushed there renders
  inside the tab: it is clipped to the body and its scrim stops at the
  `NavigationBar`/FAB, which stay tappable while the sheet is open. On the root
  navigator the sheet is the app's top-most route: the scrim covers the whole
  app (nothing underneath can open a second sheet) and back has one unambiguous
  target.
- **Dismissal — three ways, one pop**: barrier tap (`isDismissible`), drag down
  (`enableDrag`), Android back / predictive back. Nothing in the shell registers
  a `PopScope`, so a sheet is never trapped and no pop is intercepted.
- **One grabber pill**, themed in `AppTheme.bottomSheetTheme`
  (`dragHandleColor: border`, `dragHandleSize: 32×5`), centred with ≥8 dp clear
  above the title. The framework reserves a full-width 48 dp strip above the
  body: the title stays outside the scrollable so that strip remains a drag
  target while the body scrolls.
- **Keyboard + safe area, padded once**: `isScrollControlled: true`, and
  `AppSheet` pads the bottom by `max(keyboard inset, safe area)`. A sheet never
  adds its own `SafeArea`/inset padding (a sheet opened inside another sheet's
  inset must not pad twice).
- **One surface, one radius, one inset**: `surface`, the `AppRadius.sheet` top
  corners, `AppSpace.screen` horizontal padding and the title
  (`AppType.subtitle`) come from `AppSheet`; the scrim is palette-derived (`bg`
  in dark, `secondary` in light), never the framework's default black. A sheet
  adds fields, states, copy and its CTA — not chrome.
- **Reduce Motion**: `showAppSheet(…, reduceMotion: AppMotionConfig.reduceMotionOf(context))`
  passes `MotionSpec.crossFade`'s durations through the framework's `sheetAnimationStyle`, so the
  sheet arrives as a 160 ms cross-fade instead of 425/240 ms travel. Timing is a **token, never a
  caller-made `AnimationController`**: a controller is animated by the `vsync` it was built with, and
  a sheet opened from a tab resolves `Navigator.of(context)` to that tab's *branch* navigator while
  the sheet is pushed on the *root* one — the pop then never ticks and the sheet cannot be closed by
  tap, drag or back. `Haptics.sheet()` still fires — haptics are not motion.

## 5. Motion + haptics (spec tokens)

Implementation lives behind **`lib/core/motion/`** — read `core/motion/PROTOCOL.md` before touching
any animation. Budgets and the haptic meaning table are normative there; screens use the primitives
(`TapScale`, `PressableCard`/`PressableRow`, `StaggeredEntrance`/`RiseIn`, `AnimatedCounter`,
`Shimmer`, `AnimatedCheck`, `Haptics`) rather than hand-rolling animation.

Springs preferred; fallback M3 curves. Transform/opacity only; honour Reduce Motion
(cross-fade fallback); no entrance replay, no ambient loops.

| Interaction | Spec |
|---|---|
| Tap confirm | 100–150 ms, press scale ~0.97 |
| Toggle/chip | 150–200 ms |
| Cards/rows appear | 200–300 ms, rise + fade, stagger ~40 ms |
| Screen push/pop | 300–350 ms directional |
| Sheet up | 350–500 ms spring + scrim fade |

Haptics pair with visual change, consistent meaning: light = toggle/snap, selection =
picker, success = save/pay, error = validation failure. No haptics on scroll ticks or
background events. Respect device settings; `prepare()` before interaction on iOS.

## 6. Definition of done (v1)

- [ ] CTA one-handed in thumb zone; tabs 3–5 with distinct active state; back on every screen
- [ ] Tokens only (space/radius/type above); body ≥ 16px; contrast verified
- [ ] Springs/token durations, transform/opacity only, Reduce Motion fallback
- [ ] Haptics on Pay/Cancel/Reactivate/Change plan/Convert/save, consistent, setting-aware
- [ ] Skeleton/empty/error states on Home/Members/Leads/Plans; safe areas + insets
- [ ] Every money line is ₹ with `en_IN` grouping and no decimals on whole rupees, worded
      `pending` / `advance` / `Payable to …` / `<n> of <total> days` per `docs/voice.md`, and
      dated to the end of the plan period in force
- [ ] Instalment day, due bucket and `DueRing` fill computed from the stretches + payments the
      same way everywhere they appear (Home and member detail agree)
- [ ] Cancel, Reactivate and the queued plan change are all reachable from member detail, and
      Undo reverses a queued change
- [ ] No stored expiry anywhere; cancelled members badged in Members and absent from Home
- [ ] Part payments, the running `pending`/`advance`, and stretch history all visible on member detail
- [ ] Tested on real devices, both platforms, max text size
