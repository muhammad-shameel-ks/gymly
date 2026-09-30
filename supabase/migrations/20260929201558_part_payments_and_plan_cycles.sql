-- Applied 2026-09-29 as migration `part_payments_and_plan_cycles` (version 20260929201558).
--
-- Part payments + automatic plan cycles replace ADR-0001's manual per-payment
-- renewals (see docs/adr/0003-part-payments-and-plan-cycles.md):
--   * a `memberships` row is one stretch: a plan snapshot (price + duration),
--     a start date, and an optional end date + reason;
--   * `ended_on` / `end_reason` close a stretch when it is cancelled or when a
--     plan change takes over at its cycle boundary;
--   * `expiry_date` is gone — the due date is computed, never stored;
--   * `payments` is the append-what-you-received ledger (correctable, because a
--     mistyped amount is a clerical error, not payment history).

alter table public.memberships
  add column price integer,
  add column duration_days integer,
  add column ended_on date,
  add column end_reason text;

update public.memberships m
   set price = p.amount,
       duration_days = p.duration_days
  from public.plans p
 where m.plan_id = p.id
   and m.price is null;

alter table public.memberships
  add constraint memberships_price_check check (price is null or price >= 0),
  add constraint memberships_duration_check check (duration_days is null or duration_days > 0),
  add constraint memberships_rate_pair_check check ((price is null) = (duration_days is null)),
  add constraint memberships_end_pair_check check ((ended_on is null) = (end_reason is null)),
  add constraint memberships_end_reason_check check (end_reason is null or end_reason in ('cancelled', 'plan_change')),
  add constraint memberships_ended_after_start_check check (ended_on is null or ended_on >= start_date);

alter table public.memberships drop column expiry_date;

create index memberships_member_start_idx on public.memberships (member_id, start_date desc);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  amount integer not null check (amount > 0),
  paid_on date not null,
  note text,
  created_at timestamptz not null default now()
);

create index payments_member_paid_idx on public.payments (member_id, paid_on desc);
create index payments_gym_member_idx on public.payments (gym_id, member_id);

alter table public.payments enable row level security;

create policy payments_owner_all on public.payments for all
  using (exists (select 1 from public.gyms g where g.id = payments.gym_id and g.owner_id = auth.uid()))
  with check (exists (select 1 from public.gyms g where g.id = payments.gym_id and g.owner_id = auth.uid()));
