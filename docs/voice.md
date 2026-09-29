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
2. **Glossary terms exactly** (`GLOSSARY.md`): gym, plan, member, subscription,
   dues, renewal, lead, inquiry, owner. Never "user", "customer", "client",
   "package", "item".
3. **Money + term + date together** when they decide the sentence:
   `3 months · ₹3,333 · due 12 Mar`. ₹ always, Indian grouping with `intl`
   (`NumberFormat.decimalPattern('en_IN')`), no decimals on whole amounts.
4. **Time relative when it is close** (`due in 3 days`, `expired 12 days ago`),
   absolute otherwise (`12 Mar`).
5. **Empty state = the next action, in the owner's words.** Never a noun phrase
   ("No items", "No members", "Nothing here"). Say what to do, then show the
   control that does it.
6. **Error = what happened → what to do → the control that does it.**
   "Couldn't load members. Check your connection, then try again." + `Retry`.
   Never blame the owner, never print the exception, never call a fixable field
   "invalid" — name the fix ("Enter a 10-digit phone number").
7. **Confirmation = past tense + the fact.** `Member added`,
   `Renewed until 12 Mar`, `Signed out`. Nothing else.
8. **Buttons are verbs**: `Add member`, `Renew`, `Save plan`, `Mark contacted`,
   `Convert to member`, `Add gym`, `Log out`.
9. **Cut.** One idea per string. A comma pair, or any clause about the system,
   means the sentence is too long. A label is not a sentence.

**Banned:** emoji · `!` · "Oops" · "Something went wrong" as a dead end ·
"No items" · "Invalid input" · "Error occurred" · "Package" · "Customer" ·
"Client" · "User".

## Copy table — slice agents: copy the right column

| Current | Voice |
|---|---|
| `Could not save member: $e` | `Couldn't save member. Check your connection, then try again.` |
| `Could not renew: $e` | `Couldn't renew. Check your connection, then try again.` |
| `Could not save plan: $e` | `Couldn't save plan. Check your connection, then try again.` |
| `Could not archive plan: $e` | `Couldn't archive the plan. Check your connection, then try again.` |
| `Could not convert. Try again.` | `Couldn't convert this lead. Check your connection, then try again.` |
| `Could not update. Try again.` | `Couldn't mark this contacted. Check your connection, then try again.` |
| `No dues to triage` / `Add members to start tracking dues across gyms.` | `Nothing due today.` / `Add your first member to start tracking renewals.` |
| `No gyms yet` | `Add your first gym to start tracking dues.` |
| `Min 6 characters` | `Enter at least 6 characters.` |
| `Enter a valid email` | `Enter a full email address, like you@gym.com.` |
| `Pick a plan to renew` | `Choose a plan to renew.` |
| `Phone already a member — opened existing.` | `Ravi is already a member. Opened the existing record.` |
| `${inquiry.name} added to inquiries` | `Ravi added to leads.` |
| `No plan` | `Add a plan` |
| `₹${amount.toInt()}` | `₹3,333` — `NumberFormat.decimalPattern('en_IN')`, no decimals when whole |

## The one visible thing

Voice is lever one; lever two is the single motif we keep visible — `DueRing`
(`app/lib/core/signature/`), the elapsed-fraction ring. It is information, not
decoration: never place one where there is no subscription period to encode.
Motion and haptics stay in `core/motion` (its `PROTOCOL.md`); never hand-roll a
second timing system.
