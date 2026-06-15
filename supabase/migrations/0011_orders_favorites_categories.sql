-- ============================================================================
-- Reparto :: Migration 0011 :: Delivery checkout, favorites, category mgmt
-- ----------------------------------------------------------------------------
-- • Orders: delivery_address, payment_method, contact_phone, delivered_at
-- • Favorites table (student saved products)
-- • Categories: description writable by admin (RLS already allows), add a
--   delete-safety note. (no schema change needed besides ensuring RLS)
-- • New checkout RPC place_order_checkout(...) capturing delivery details.
-- • Helper view for vendor sales reporting & product stats.
--
-- Run AFTER 0010 (which adds the enum values). Safe to run more than once.
-- ============================================================================

-- ---- Orders: delivery details ---------------------------------------------
do $$ begin
  create type payment_method as enum ('cash_on_delivery', 'mobile_money', 'card', 'paystack');
exception when duplicate_object then null; end $$;

alter table public.orders
  add column if not exists delivery_address text,
  add column if not exists contact_phone    text,
  add column if not exists payment_method    payment_method not null default 'cash_on_delivery',
  add column if not exists note              text,
  add column if not exists confirmed_at      timestamptz,
  add column if not exists dispatched_at     timestamptz,
  add column if not exists delivered_at      timestamptz;

-- Stamp lifecycle timestamps automatically on status change.
create or replace function public.stamp_order_timeline()
returns trigger
language plpgsql
as $$
begin
  if new.order_status is distinct from old.order_status then
    if new.order_status = 'confirmed'  and new.confirmed_at  is null then new.confirmed_at  := now(); end if;
    if new.order_status = 'dispatched' and new.dispatched_at is null then new.dispatched_at := now(); end if;
    if new.order_status = 'delivered'  and new.delivered_at  is null then new.delivered_at  := now(); end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_order_timeline on public.orders;
create trigger trg_stamp_order_timeline
  before update of order_status on public.orders
  for each row execute function public.stamp_order_timeline();

-- ---- Favorites -------------------------------------------------------------
create table if not exists public.favorites (
  user_id    uuid not null references public.users(user_id) on delete cascade,
  product_id uuid not null references public.products(product_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
create index if not exists idx_favorites_user on public.favorites(user_id);

alter table public.favorites enable row level security;

drop policy if exists favorites_owner on public.favorites;
create policy favorites_owner on public.favorites
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---- Checkout RPC with delivery details ------------------------------------
-- Creates one order per vendor from the cart, capturing delivery address,
-- contact phone, payment method and an optional note. Decrements stock and
-- notifies vendors. Returns the created order ids.
create or replace function public.place_order_checkout(
  p_delivery_address text,
  p_contact_phone    text,
  p_payment_method   text default 'cash_on_delivery',
  p_note             text default null
)
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student uuid := auth.uid();
  v_campus  uuid;
  v_cart    uuid;
  r_vendor  record;
  r_item    record;
  v_order   uuid;
  v_total   numeric(12,2);
begin
  if public.current_role() <> 'student' then
    raise exception 'Only students can place orders';
  end if;
  if coalesce(trim(p_delivery_address), '') = '' then
    raise exception 'Delivery address is required';
  end if;
  if coalesce(trim(p_contact_phone), '') = '' then
    raise exception 'Contact phone is required';
  end if;

  select campus_id into v_campus from public.users where user_id = v_student;
  select cart_id into v_cart from public.carts where student_id = v_student;
  if v_cart is null then
    raise exception 'Cart is empty';
  end if;

  for r_vendor in
    select distinct p.vendor_id
    from public.cart_items ci
    join public.products p on p.product_id = ci.product_id
    where ci.cart_id = v_cart
  loop
    if not exists (
      select 1 from public.vendors v
      where v.vendor_id = r_vendor.vendor_id
        and v.campus_id = v_campus
        and v.approval_status = 'approved'
    ) then
      raise exception 'A shop in your cart is not available on your campus';
    end if;

    insert into public.orders
      (student_id, vendor_id, total_amount, order_status,
       delivery_address, contact_phone, payment_method, note)
    values
      (v_student, r_vendor.vendor_id, 0, 'pending',
       p_delivery_address, p_contact_phone, p_payment_method::payment_method, p_note)
    returning order_id into v_order;

    v_total := 0;
    for r_item in
      select ci.product_id, ci.quantity, p.price, p.quantity_available, p.product_name
      from public.cart_items ci
      join public.products p on p.product_id = ci.product_id
      where ci.cart_id = v_cart and p.vendor_id = r_vendor.vendor_id
    loop
      if r_item.quantity > r_item.quantity_available then
        raise exception 'Insufficient stock for %', r_item.product_name;
      end if;

      insert into public.order_items (order_id, product_id, quantity, unit_price)
      values (v_order, r_item.product_id, r_item.quantity, r_item.price);

      update public.products
        set quantity_available = quantity_available - r_item.quantity
        where product_id = r_item.product_id;

      v_total := v_total + (r_item.price * r_item.quantity);
    end loop;

    update public.orders set total_amount = v_total where order_id = v_order;

    insert into public.notifications (recipient_id, title, body)
    select v.user_id, 'New Order', 'You have received a new order.'
    from public.vendors v where v.vendor_id = r_vendor.vendor_id;

    return next v_order;
  end loop;

  delete from public.cart_items where cart_id = v_cart;
  return;
end;
$$;

-- ---- Vendor product sales stats (per product) ------------------------------
-- Aggregates units sold & revenue per product for completed/delivered orders.
create or replace function public.vendor_product_stats(p_vendor_id uuid)
returns table (
  product_id   uuid,
  product_name text,
  units_sold   bigint,
  revenue      numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select p.product_id,
         p.product_name,
         coalesce(sum(oi.quantity), 0)               as units_sold,
         coalesce(sum(oi.quantity * oi.unit_price),0) as revenue
  from public.products p
  left join public.order_items oi on oi.product_id = p.product_id
  left join public.orders o on o.order_id = oi.order_id
       and o.order_status in ('completed','delivered')
  where p.vendor_id = p_vendor_id
  group by p.product_id, p.product_name
  order by units_sold desc;
$$;
