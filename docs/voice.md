# Gymly voice

Voice is our cheapest differentiator: the labels, errors, empty states and
confirmations *are* the product talking to the owner. Held everywhere, it is
what makes the app unmistakably ours.

**The test.** Rename the app to a competitor's. If the copy still fits them
unchanged, it is stock — rewrite it.

## Rules

1. **Second person, plain English.** The owner is *you*; the people who pay are
   *members*. Sentence case for labels, buttons and captions; Title Case only
   for screen titles.
2. **Glossary terms exactly** (`GLOSSARY.md`): gym, plan, member, subscription
   (a stretch), dues, pending, advance, instalment, payment, plan change, cancellation,
   lead, inquiry, owner. Never "user", "customer", "client", "package", "item",
   "balance", "outstanding", "arrears", "credit", "overpayment", "renewal".
3. **Money + term + date together** when they decide the sentence:
   `3 months · ₹3,333 · due 12 Mar`. ₹ always, Indian grouping with `intl`
   (`NumberFormat.decimalPattern('en_IN')`), no decimals on whole amounts.
4. **Time relative when it is close** (`due in 3 days`, `overdue by 12 days`),
   absolute otherwise (`12 Mar`).
5. **Empty state = the next action, in the owner's words.** Never a noun phrase
   ("No items", "No members", "Nothing here"). Say what to do, then show the
   control that does it.
6. **Error = what happened → what to do → the control that does it.**
   "Couldn't load members. Check your connection, then try again." + `Retry`.
   Never blame the owner, never print the exception, never call a fixable field
   "invalid" — name the fix ("Enter a 10-digit phone number").
7. **Confirmation = past tense + the fact.** `Member added`,
   `Payment recorded`, `Cancelled on 12 Sep`, `Signed out`. Nothing else.
8. **Buttons are verbs**: `Add member`, `Pay`, `Cancel`, `Reactivate`,
   `Change plan`, `Save plan`, `Mark contacted`, `Convert to member`, `Add gym`,
   `Log out`, `Undo`.
9. **Cut.** One idea per string. A comma pair, or any clause about the system,
   means the sentence is too long. A label is not a sentence.

**Banned:** emoji · `!` · "Oops" · "Something went wrong" as a dead end ·
"No items" · "Invalid input" · "Error occurred" · "Package" · "Customer" ·
"Client" · "User" · "back-date" · "effective date" · "prorate" · "accrual" ·
"cycle boundary" · "snapshot" · "ledger" · "balance" · "outstanding".

## Copy table — slice agents: copy the right column

| Current | Voice |
|---|---|
| `Could not save member: $e` | `Couldn't save member. Check your connection, then try again.` |
| `Could not record payment: $e` | `Couldn't record the payment. Check your connection, then try again.` |
| `Could not save plan: $e` | `Couldn't save plan. Check your connection, then try again.` |
| `Could not archive plan: $e` | `Couldn't archive the plan. Check your connection, then try again.` |
| `Could not convert. Try again.` | `Couldn't convert this lead. Check your connection, then try again.` |
| `Could not update. Try again.` | `Couldn't mark this contacted. Check your connection, then try again.` |
| `No dues to triage` / `Add members to start tracking dues across gyms.` | `Nothing due today.` / `Add your first member to start tracking dues.` |
| `No gyms yet` | `Add your first gym to start tracking dues.` |
| `Min 6 characters` | `Enter at least 6 characters.` |
| `Enter a valid email` | `Enter a full email address, like you@gym.com.` |
| `Pick a plan` | `Choose a plan.` |
| `Phone already a member — opened existing.` | `Ravi is already a member. Opened the existing record.` |
| `${inquiry.name} added to inquiries` | `Ravi added to leads.` |
| `No plan` | `Add a plan` |
| `₹${amount.toInt()}` | `₹3,333` — `NumberFormat.decimalPattern('en_IN')`, no decimals when whole |

## Copy table — part payments, cycles, cancellation

Money + term + date together wherever the sentence turns on them (`₹2,000 pending · due 28 Dec`).
`pending` and `advance` are the only words for the running amount; `Payable to <date>` and
`<n> of <total> days` are the only words for a cancel preview. The date on a money line is the
**end of the plan period he is in** — the day the balance comes due — while the instalment he is
behind on shows as the card's colour and as the Pay sheet's pre-filled amount. Copy the right column.
**Never print a zero amount**: a tab that owes nothing this instant (a member who has paid his
plan) drops the money half and keeps the date — `due 28 Dec` — because
`₹0 pending · due 28 Dec` says two opposite things in one line.

| Surface | Voice |
|---|---|
| Home card money line | `₹2,000 pending · due 28 Dec` |
| Home card, nothing owed today | `due 28 Dec` (never `₹0 pending`) |
| Home card, paid ahead | `₹500 advance · due 28 Dec` |
| Member detail money line | `₹2,000 pending` / `₹500 advance` |
| Pay sheet title | `Record payment` |
| Pay sheet, amount pre-filled | what he owes now — the instalment he is behind on (`₹1,000`) — never the whole plan |
| Pay sheet fields | `Amount` · `Paid on` · `Note (optional)` |
| Pay button | `Record payment` |
| Pay confirmation | `Payment recorded` |
| Cancel sheet title / button | `Cancel membership` |
| Cancel sheet note | `Stops on the last day he came.` |
| Cancel date field | `Last day he came` |
| Cancel preview | `Payable to 21 Oct — ₹2,000` |
| Cancel preview days | `40 of 90 days` |
| Cancel confirmation | `Cancelled on 12 Sep` |
| Reactivate button | `Reactivate` |
| Reactivate sheet fields | `Plan` · `Price` · `Received now` |
| Reactivate sheet note | `A new subscription starts today. The days he was away are not billed.` |
| Reactivate sheet, money owed | `₹1,567 pending stays on his record.` |
| Reactivate confirmation | `Reactivated today` |
| No-subscription card | `Reactivate to start a subscription.` |
| History, nothing ended yet | `No earlier subscriptions yet.` |
| Change plan sheet | `Change plan` · `Choose a plan.` · `New plan starts 12 Dec — after his current plan ends` · `Not that date?` · `He asked to switch on` |
| Queued change line | `Switches to 3 months · ₹3,333 on 12 Oct` + `Nothing changes until then.` + `Undo` |
| Change plan confirmation | `Plan change scheduled for 12 Oct` |
| Undo confirmation | `Plan change undone` |
| Assign/member form, first payment | `Received now` · helper `Leave 0 if he paid nothing now.` |
| Edit payment button | `Save payment` |
| Edit payment confirmation | `Payment updated` |
| Delete payment sheet | `Delete payment?` / `₹1,000 recorded on 12 Sep will be removed.` |
| Delete payment button | `Delete payment` |
| Delete payment confirmation | `Payment deleted` |
| Error, pay | `Couldn't record the payment. Check your connection, then try again.` |
| Error, cancel | `Couldn't cancel this member. Check your connection, then try again.` |
| Error, reactivate | `Couldn't reactivate this member. Check your connection, then try again.` |
| Error, change plan | `Couldn't change the plan. Check your connection, then try again.` |
| Error, save payment | `Couldn't save the payment. Check your connection, then try again.` |
| Error, delete payment | `Couldn't delete this payment. Check your connection, then try again.` |

## The one visible thing

Voice is lever one; lever two is the single motif we keep visible — `DueRing`
(`app/lib/core/signature/`), the ring that fills with money paid against the
plan he is on. It is information, not decoration: never place one where there is
nothing owed to encode.
Motion and haptics stay in `core/motion` (its `PROTOCOL.md`); never hand-roll a
second timing system.
