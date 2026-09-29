# GLOSSARY.md — Gymly

Canonical domain language. Use these terms exactly; avoid the listed synonyms.

- **Owner** — A gym owner. One Supabase Auth user. Owns one or more gyms. The only login role in v1.
- **Gym** — One physical gym location belonging to an Owner. All data is scoped to a gym.
- **Plan** — A membership price template: name + amount (₹) + duration in days. Example: "3 months / ₹3333". Not tied to any person.
- **Member** — A paying person registered at a gym. Identity = phone number; one phone = one member per gym. Has a name and an optional note.
- **Subscription** — One member on one plan for one period: start date → expiry date. Stored as a row in the `memberships` table. A member holds many subscriptions over time; the current one is the row with the latest expiry date.
- **Renewal** — Appending a new subscription row when a member pays again. Never editing the old row. History is preserved.
- **Due bucket** — Where a member sits on the Home triage: **Overdue** (expiry passed), **Due soon** (expiry within 7 days), **Active** (everything else).
- **Inquiry** — A walk-in / call asking about the gym, not yet a member. Name + phone required, optional note. Statuses: `new`, `contacted`, `joined`, `lost`. Converting an inquiry creates a member (and usually a first subscription) and marks the inquiry `joined`.
