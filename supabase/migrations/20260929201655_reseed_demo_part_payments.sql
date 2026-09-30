-- Applied 2026-09-29 as migration `reseed_demo_part_payments` (version 20260929201655).
--
-- Rebuilds the demo gym's subscriptions into the part-payments model so every
-- state the UI has to get right has a live example (as of 2026-09-30):
--   Priya Nair   two cycles in, ₹1,000 paid   -> Overdue, ₹2,267 pending
--   Arjun Menon  29 days in, ₹500 paid        -> Due soon (deadline 2 Oct)
--   Sana Iqbal   half year paid up front      -> ₹5,000 advance, switch queued to Annual
--   Vikram Rao   cancelled on 20 Jul          -> ₹963 payable, Cancelled badge
--
-- Demo data only; ids are resolved by phone/plan name, never hardcoded.

with demo_members as (
  select id, gym_id, phone from public.members
   where phone in ('9000000001','9000000002','9000000003','9000000004')
), demo_gyms as (
  select distinct gym_id from demo_members
)
insert into public.plans (gym_id, name, amount, duration_days)
select g.gym_id, '3 months', 3000, 90 from demo_gyms g
 where not exists (select 1 from public.plans p where p.gym_id = g.gym_id and p.name = '3 months');

delete from public.payments p
 using public.members m
 where p.member_id = m.id
   and m.phone in ('9000000001','9000000002','9000000003','9000000004');

delete from public.memberships ms
 using public.members m
 where ms.member_id = m.id
   and m.phone in ('9000000001','9000000002','9000000003','9000000004');

-- Priya Nair: two cycles in, part-paid -> Overdue, ~2,267 pending
insert into public.memberships (gym_id, member_id, plan_id, start_date, price, duration_days)
select m.gym_id, m.id, p.id, date '2026-06-25', 3000, 90
  from public.members m
  join public.plans p on p.gym_id = m.gym_id and p.name = '3 months'
 where m.phone = '9000000001';

insert into public.payments (gym_id, member_id, amount, paid_on, note)
select m.gym_id, m.id, 1000, date '2026-06-25', 'first instalment'
  from public.members m where m.phone = '9000000001';

-- Arjun Menon: 29 days in, part-paid, deadline on 2 Oct -> Due soon
insert into public.memberships (gym_id, member_id, plan_id, start_date, price, duration_days)
select m.gym_id, m.id, p.id, date '2026-09-02', 3000, 90
  from public.members m
  join public.plans p on p.gym_id = m.gym_id and p.name = '3 months'
 where m.phone = '9000000002';

insert into public.payments (gym_id, member_id, amount, paid_on)
select m.gym_id, m.id, 500, date '2026-09-02' from public.members m where m.phone = '9000000002';

-- Sana Iqbal: half year paid up front -> 5,000 advance, and a queued switch to Annual
insert into public.memberships (gym_id, member_id, plan_id, start_date, price, duration_days, ended_on, end_reason)
select m.gym_id, m.id, p.id, date '2026-09-01', 6000, 180, date '2027-02-27', 'plan_change'
  from public.members m
  join public.plans p on p.gym_id = m.gym_id and p.name = 'Half year'
 where m.phone = '9000000003';

insert into public.memberships (gym_id, member_id, plan_id, start_date, price, duration_days)
select m.gym_id, m.id, p.id, date '2027-02-28', 11000, 365
  from public.members m
  join public.plans p on p.gym_id = m.gym_id and p.name = 'Annual'
 where m.phone = '9000000003';

insert into public.payments (gym_id, member_id, amount, paid_on, note)
select m.gym_id, m.id, 6000, date '2026-09-01', 'paid in full'
  from public.members m where m.phone = '9000000003';

-- Vikram Rao: cancelled on 20 Jul (payable to that day), 963 still owed
insert into public.memberships (gym_id, member_id, plan_id, start_date, price, duration_days, ended_on, end_reason)
select m.gym_id, m.id, p.id, date '2026-05-02', 3333, 90, date '2026-07-20', 'cancelled'
  from public.members m
  join public.plans p on p.gym_id = m.gym_id and p.name = 'Quarterly'
 where m.phone = '9000000004';

insert into public.payments (gym_id, member_id, amount, paid_on)
select m.gym_id, m.id, 2000, date '2026-05-02' from public.members m where m.phone = '9000000004';
