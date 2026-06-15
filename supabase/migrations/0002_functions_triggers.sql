-- ============================================================================
-- Reparto :: Migration 0002 :: Helper Functions & Triggers
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Security-definer helpers (used inside RLS policies to avoid recursion)
-- ----------------------------------------------------------------------------

-- Current user's role
create or replace function public.current_role()
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where user_id = auth.uid();
$$;

-- Current user's campus
create or replace function public.current_campus()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select campus_id from public.users where user_id = auth.uid();
$$;

-- Is the current user an admin?
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role = 'admin' from public.users where user_id = auth.uid()), false);
$$;

-- vendor_id owned by the current user (null if not a vendor)
create or replace function public.current_vendor_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select vendor_id from public.vendors where user_id = auth.uid();
$$;

-- ----------------------------------------------------------------------------
-- Auto-create a public.users row when a new auth user is created.
-- Reads metadata supplied at sign-up (full_name, role, campus_id).
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campus uuid;
begin
  -- campus may be null at first (e.g. Google sign-in before campus selection)
  begin
    v_campus := nullif(new.raw_user_meta_data ->> 'campus_id', '')::uuid;
  exception when others then
    v_campus := null;
  end;

  insert into public.users (user_id, full_name, email, role, campus_id, profile_image)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce((new.raw_user_meta_data ->> 'role')::user_role, 'student'),
    v_campus,
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (user_id) do nothing;

  -- If the user signed up as a vendor and supplied business details + campus,
  -- create the pending vendor record immediately (works even when email
  -- confirmation is enabled and no client session exists yet).
  if coalesce((new.raw_user_meta_data ->> 'role'), '') = 'vendor'
     and (new.raw_user_meta_data ->> 'business_name') is not null
     and v_campus is not null then
    insert into public.vendors
      (user_id, business_name, owner_name, phone_number, campus_id, approval_status)
    values (
      new.id,
      new.raw_user_meta_data ->> 'business_name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'phone_number',
      v_campus,
      'pending'
    )
    on conflict (user_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- Keep product availability in sync with stock.
-- ----------------------------------------------------------------------------
create or replace function public.sync_product_availability()
returns trigger
language plpgsql
as $$
begin
  if new.quantity_available <= 0 then
    new.availability_status := 'unavailable';
  elsif new.availability_status = 'unavailable' and old.quantity_available <= 0 then
    new.availability_status := 'available';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_product_availability on public.products;
create trigger trg_product_availability
  before insert or update of quantity_available on public.products
  for each row execute function public.sync_product_availability();

-- ----------------------------------------------------------------------------
-- Ensure a cart exists for a student (called from the app).
-- ----------------------------------------------------------------------------
create or replace function public.get_or_create_cart()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart uuid;
begin
  select cart_id into v_cart from public.carts where student_id = auth.uid() limit 1;
  if v_cart is null then
    insert into public.carts (student_id) values (auth.uid()) returning cart_id into v_cart;
  end if;
  return v_cart;
end;
$$;

-- ----------------------------------------------------------------------------
-- Place an order from the current student's cart.
-- Validates campus isolation, stock, decrements inventory, clears cart,
-- and notifies the relevant vendor(s). Returns the created order ids.
-- ----------------------------------------------------------------------------
create or replace function public.place_order_from_cart()
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student   uuid := auth.uid();
  v_campus    uuid;
  v_cart      uuid;
  r_vendor    record;
  r_item      record;
  v_order     uuid;
  v_total     numeric(12,2);
begin
  if public.current_role() <> 'student' then
    raise exception 'Only students can place orders';
  end if;

  select campus_id into v_campus from public.users where user_id = v_student;
  select cart_id into v_cart from public.carts where student_id = v_student;
  if v_cart is null then
    raise exception 'Cart is empty';
  end if;

  -- One order per vendor in the cart
  for r_vendor in
    select distinct p.vendor_id
    from public.cart_items ci
    join public.products p on p.product_id = ci.product_id
    where ci.cart_id = v_cart
  loop
    -- campus isolation: vendor must be on the student's campus and approved
    if not exists (
      select 1 from public.vendors v
      where v.vendor_id = r_vendor.vendor_id
        and v.campus_id = v_campus
        and v.approval_status = 'approved'
    ) then
      raise exception 'Vendor % not available on your campus', r_vendor.vendor_id;
    end if;

    insert into public.orders (student_id, vendor_id, total_amount, order_status)
    values (v_student, r_vendor.vendor_id, 0, 'pending')
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

    -- notify the vendor's owner
    insert into public.notifications (recipient_id, title, body)
    select v.user_id, 'New Order', 'You have received a new order.'
    from public.vendors v where v.vendor_id = r_vendor.vendor_id;

    return next v_order;
  end loop;

  -- clear the cart
  delete from public.cart_items where cart_id = v_cart;
  return;
end;
$$;

-- ----------------------------------------------------------------------------
-- Notify on order status change.
-- ----------------------------------------------------------------------------
create or replace function public.notify_order_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
begin
  if new.order_status = old.order_status then
    return new;
  end if;

  v_title := case new.order_status
    when 'accepted'        then 'Order Accepted'
    when 'preparing'       then 'Order Preparing'
    when 'ready_for_pickup' then 'Order Ready for Pickup'
    when 'completed'       then 'Order Completed'
    when 'cancelled'       then 'Order Cancelled'
    else 'Order Updated'
  end;

  -- notify student
  insert into public.notifications (recipient_id, title, body)
  values (new.student_id, v_title, 'Your order status is now ' || new.order_status || '.');

  -- on cancellation also notify the vendor owner
  if new.order_status = 'cancelled' then
    insert into public.notifications (recipient_id, title, body)
    select v.user_id, 'Order Cancelled', 'An order was cancelled.'
    from public.vendors v where v.vendor_id = new.vendor_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_order_status on public.orders;
create trigger trg_notify_order_status
  after update of order_status on public.orders
  for each row execute function public.notify_order_status();

-- ----------------------------------------------------------------------------
-- Notify vendor when application is approved/suspended.
-- ----------------------------------------------------------------------------
create or replace function public.notify_vendor_approval()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.approval_status = old.approval_status then
    return new;
  end if;

  insert into public.notifications (recipient_id, title, body)
  values (
    new.user_id,
    case new.approval_status
      when 'approved'  then 'Vendor Approved'
      when 'rejected'  then 'Vendor Application Rejected'
      when 'suspended' then 'Account Suspended'
      else 'Vendor Status Updated'
    end,
    'Your vendor status is now ' || new.approval_status || '.'
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_vendor_approval on public.vendors;
create trigger trg_notify_vendor_approval
  after update of approval_status on public.vendors
  for each row execute function public.notify_vendor_approval();

-- ----------------------------------------------------------------------------
-- Enforce: a review can only be submitted after a completed order.
-- ----------------------------------------------------------------------------
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
      and o.order_status = 'completed'
  ) then
    raise exception 'Reviews can only be submitted after a completed order';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_review on public.reviews;
create trigger trg_validate_review
  before insert on public.reviews
  for each row execute function public.validate_review();
