-- ============================================================================
-- Reparto :: Migration 0013 :: Review validation fix + Mobile-Money payouts
-- ----------------------------------------------------------------------------
-- 1. Reviews may be left once an order is DELIVERED (new flow) or COMPLETED
--    (legacy). The old trigger only accepted 'completed', which blocked reviews
--    on delivered orders even though they were finished.
-- 2. Record the vendor's mobile-money payout target on each order so customer
--    Mobile-Money payments are always associated with the vendor's MoMo number.
--
-- Run AFTER 0012. Safe to run more than once.
-- ============================================================================

-- ---- 0. Add the 'momo' payment method value --------------------------------
-- (New enum values must be committed before they're used in inserts.)
alter type payment_method add value if not exists 'momo';

-- ---- 1. Review validation --------------------------------------------------
create or replace function public.validate_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.orders o
    where o.student_id = new.student_id
      and o.vendor_id  = new.vendor_id
      and o.order_status in ('delivered', 'completed')
  ) then
    raise exception 'You can only review a shop after an order has been delivered';
  end if;
  return new;
end;
$$;

-- ---- 2. Vendor MoMo payout target on orders --------------------------------
alter table public.orders
  add column if not exists vendor_momo_number  text,
  add column if not exists vendor_momo_network text;

-- Helper to fetch a vendor's momo details (used by checkout RPCs).
-- Stamps the vendor payout details on every new order automatically so the
-- customer's Mobile-Money payment is always tied to the vendor's MoMo number.
create or replace function public.stamp_vendor_momo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.vendor_momo_number is null then
    select v.momo_number, v.momo_network
      into new.vendor_momo_number, new.vendor_momo_network
    from public.vendors v
    where v.vendor_id = new.vendor_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_vendor_momo on public.orders;
create trigger trg_stamp_vendor_momo
  before insert on public.orders
  for each row execute function public.stamp_vendor_momo();
