# DESIGN.md — Gymly (v1)

Product + UX + data contract for the gym-owner mobile app. Stack: **Flutter + Supabase**.
Domain language per `GLOSSARY.md`; renewal rule per `docs/adr/0001-append-only-renewals.md`.

## 1. Scope (v1)

**In:** owner auth, multiple gyms per owner, plans, members, subscriptions with due-date
triage, renewal (append-only), minimal inquiries with convert-to-member, dues dashboard.

**Out:** staff logins, in-app payments/gateways, attendance, trainers, expenses,
auto-reminders, diet/workout plans, offline write-queue. App is a **due-date tracker**;
money changes hands at the desk.

## 2. Data model (Supabase `public`, verified 2026-09-29)

| Table | Key columns | Rule |
|---|---|---|
| `gyms` | `id`, `owner_id → auth.users`, `name` | One row per location. |
| `plans` | `gym_id`, `name`, `amount ≥ 0` (₹), `duration_days > 0` | Price × duration template. |
| `members` | `gym_id`, `name`, `phone`, `note?` | `UNIQUE(gym_id, phone)` — one phone = one member per gym. |
| `memberships` | `gym_id`, `member_id`, `plan_id?`, `start_date`, `expiry_date` | Append-only; current = latest `expiry_date` per member. Indexed `(member_id, expiry_date desc)`. |
| `inquiries` | `gym_id`, `name`, `phone`, `note?`, `status new/contacted/joined/lost`, `member_id?` | Quick-add only: name + phone required, note optional. No follow-up/source fields. `member_id` set when converted (`on delete set null`). |

**RLS (owner-only):** `gyms_owner_all` (`owner_id = auth.uid()`); all other tables
owner-via-gym `EXISTS (gyms … owner_id = auth.uid())`. No staff roles in v1.

**Core rules:**

- Renewal = insert new `memberships` row (`start` = old expiry or today if lapsed,
  `expiry` = start + plan days). Never update history.
- Due bucket: **Overdue** (expiry < today) → **Due soon** (≤ 7 days) → **Active**.
- Convert inquiry = create `member` (+ first `membership`) and set inquiry `joined`.

## 3. Information architecture

Four bottom tabs: **Home (Dues) · Members · Leads · Plans**. ≤ 3 taps to any action.

- **Header:** gym switcher (drops down gym list + "All gyms"). Home aggregates all gyms
  when "All gyms" is selected; other tabs filter to one gym (prompt to pick if "All").
- **Home:** dues triage feed — Overdue, then Due ≤7d, then Active. Each card: member name,
  plan, expiry/due-in, amount; one-thumb actions **Renew / Call / WhatsApp**.
- **Members:** search-first list (name/phone), due-status ring/dot cue; detail shows
  current subscription + history + Renew.
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
  as the current subscription period elapses and takes the due-bucket colour. It is the app's one
  held visual motif and it earns its place by making "who is running out" legible at a glance.
  Never place it where there is no subscription period.
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
picker, success = save/renew, error = validation failure. No haptics on scroll ticks or
background events. Respect device settings; `prepare()` before interaction on iOS.

## 6. Definition of done (v1)

- [ ] CTA one-handed in thumb zone; tabs 3–5 with distinct active state; back on every screen
- [ ] Tokens only (space/radius/type above); body ≥ 16px; contrast verified
- [ ] Springs/token durations, transform/opacity only, Reduce Motion fallback
- [ ] Haptics on Renew/Convert/save, consistent, setting-aware
- [ ] Skeleton/empty/error states on Home/Members/Leads/Plans; safe areas + insets
- [ ] Latest-expiry resolution everywhere dues show; history visible on member detail
- [ ] Tested on real devices, both platforms, max text size
