-- ============================================================================
-- UjustBUY :: Migration 0018 :: Escrow completion + Disputes
-- ----------------------------------------------------------------------------
-- Spec Section C: buyer "Confirm Receipt" releases funds (status -> completed);
-- 48h auto-release after DELIVERED; disputes pause the flow for admin ruling.
--
-- Escrow here is STATUS-BASED (no separate funds ledger): money is conceptually
-- held while an order is paid + not completed, and "released" when it reaches
-- 'completed'. This is additive and does NOT touch the Paystack charge path
-- (no double-charge risk). Commission deduction at charge-time remains out of
-- scope by design (documented in SPEC_PIVOT_PLAN.md).
--
-- Run AFTER 0017. Idempotent.
-- ============================================================================

-- ---- 1. New status value + columns ----------------------------------------
alter type order_status add value if not exists 'disputed';

alter table public.orders
  add column if not exists completed_at  timestamptz,
  add column if not exists auto_release_at timestamptz;  -- set when DELIVERED

-- When an order becomes 'delivered', stamp the 48h auto-release deadline.
create or replace function public.stamp_delivery_deadline()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.order_status = 'delivered'
     and (old.order_status is distinct from 'delivered')
     and new.auto_release_at is null then
    new.auto_release_at := now() + interval '48 hours';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_delivery_deadline on public.orders;
create trigger trg_stamp_delivery_deadline
  before update on public.orders
  for each row execute function public.stamp_delivery_deadline();

-- ---- 2. Buyer "Confirm Receipt" -> completed (releases escrow) -------------
create or replace function public.confirm_receipt(p_order uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me      uuid := auth.uid();
  r_order   record;
begin
  select * into r_order from public.orders
   where order_id = p_order and student_id = v_me;
  if r_order is null then
    raise exception 'Order not found';
  end if;
  if r_order.order_status not in ('delivered') then
    raise exception 'You can only confirm receipt once the order is delivered';
  end if;

  update public.orders
     set order_status = 'completed', completed_at = now()
   where order_id = p_order;

  -- Tie-off P7: reward the referrer on the buyer's FIRST completed order.
  perform public.reward_first_transaction(v_me);

  insert into public.notifications (recipient_id, title, body)
  select v.user_id, 'Payment released',
         'A buyer confirmed receipt — your payment has been released.'
  from public.vendors v where v.vendor_id = r_order.vendor_id;
end;
$$;

-- ---- 3. Auto-release sweep (call from a scheduled job / cron) --------------
-- Completes any DELIVERED order whose 48h window has elapsed and that is not
-- under dispute. Safe to call repeatedly (e.g. pg_cron every 15 min).
create or replace function public.auto_release_due_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_count integer;
begin
  with released as (
    update public.orders o
       set order_status = 'completed', completed_at = now()
     where o.order_status = 'delivered'
       and o.auto_release_at is not null
       and o.auto_release_at <= now()
     returning o.order_id, o.student_id, o.vendor_id
  )
  select count(*) into v_count from released;

  -- First-purchase referral bonus for each auto-released buyer.
  perform public.reward_first_transaction(student_id)
    from public.orders
   where order_status = 'completed' and completed_at >= now() - interval '1 minute';

  return v_count;
end;
$$;

-- ---- 4. Disputes -----------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'dispute_status') then
    create type dispute_status as enum ('open', 'under_review', 'resolved');
  end if;
end $$;

create table if not exists public.disputes (
  dispute_id   uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders(order_id) on delete cascade,
  student_id   uuid not null references public.users(user_id) on delete cascade,
  category     text not null,
  description  text not null,
  evidence     text[],                  -- storage paths / urls
  status       dispute_status not null default 'open',
  resolution   text,
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz
);
create index if not exists idx_disputes_order on public.disputes(order_id);
create index if not exists idx_disputes_status on public.disputes(status);

-- Raise a dispute: allowed in active states or within 48h of completion.
create or replace function public.raise_dispute(
  p_order       uuid,
  p_category    text,
  p_description text,
  p_evidence    text[] default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := auth.uid();
  r_order  record;
  v_id     uuid;
begin
  select * into r_order from public.orders
   where order_id = p_order and student_id = v_me;
  if r_order is null then
    raise exception 'Order not found';
  end if;
  if r_order.order_status not in
       ('confirmed','dispatched','delivered','ready_for_pickup','completed')
     or (r_order.order_status = 'completed'
         and r_order.completed_at is not null
         and r_order.completed_at < now() - interval '48 hours') then
    raise exception 'This order can no longer be disputed';
  end if;
  if char_length(coalesce(trim(p_description),'')) < 30 then
    raise exception 'Please describe the issue (at least 30 characters)';
  end if;

  insert into public.disputes (order_id, student_id, category, description, evidence)
  values (p_order, v_me, p_category, p_description, p_evidence)
  returning dispute_id into v_id;

  update public.orders set order_status = 'disputed' where order_id = p_order;

  -- Notify campus admins.
  insert into public.notifications (recipient_id, title, body)
  select u.user_id, 'New dispute',
         'A buyer raised a dispute that needs review.'
  from public.users u where u.role = 'admin';

  return v_id;
end;
$$;

-- Admin ruling. p_outcome in ('refund_buyer','partial_refund','release_seller').
create or replace function public.resolve_dispute(
  p_dispute uuid,
  p_outcome text,
  p_note    text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare r_d record;
begin
  if not public.is_admin() then
    raise exception 'Only admins can resolve disputes';
  end if;
  select * into r_d from public.disputes where dispute_id = p_dispute;
  if r_d is null then raise exception 'Dispute not found'; end if;

  update public.disputes
     set status = 'resolved', resolution = coalesce(p_note, p_outcome),
         resolved_at = now()
   where dispute_id = p_dispute;

  -- Move the order to a terminal state based on the ruling.
  update public.orders
     set order_status = case
           when p_outcome = 'release_seller' then 'completed'
           else 'cancelled' end,
         completed_at = case
           when p_outcome = 'release_seller' then now() else completed_at end
   where order_id = r_d.order_id;

  insert into public.notifications (recipient_id, title, body)
  values (r_d.student_id, 'Dispute resolved',
          'An admin has resolved your dispute: ' || coalesce(p_note, p_outcome));
end;
$$;

-- ---- 5. RLS ----------------------------------------------------------------
alter table public.disputes enable row level security;

drop policy if exists disputes_read on public.disputes;
create policy disputes_read on public.disputes
  for select using (
    student_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.orders o
      join public.vendors v on v.vendor_id = o.vendor_id
      where o.order_id = disputes.order_id and v.user_id = auth.uid()
    )
  );

-- All writes happen through SECURITY DEFINER functions above (no direct DML).

-- ---- 6. Grants -------------------------------------------------------------
grant execute on function public.confirm_receipt(uuid) to authenticated;
grant execute on function public.raise_dispute(uuid, text, text, text[]) to authenticated;
grant execute on function public.resolve_dispute(uuid, text, text) to authenticated;
grant execute on function public.auto_release_due_orders() to authenticated;

-- ---- 7. OPTIONAL: schedule the 48h auto-release sweep -----------------------
-- Requires the pg_cron extension (Supabase: Database → Extensions → enable
-- "pg_cron"). Uncomment to run the sweep every 15 minutes. Until this is set
-- up, payment still releases instantly when the buyer taps "Confirm Receipt";
-- only the *automatic* 48h fallback depends on this job.
--
-- create extension if not exists pg_cron;
-- select cron.schedule(
--   'ujustbuy-auto-release',
--   '*/15 * * * *',
--   $cron$ select public.auto_release_due_orders(); $cron$
-- );
