-- ============================================================================
-- Reparto :: Migration 0008 :: Paid Checkout Flow + Push Notification Hook
-- ----------------------------------------------------------------------------
-- place_order_from_cart_paid(reference) — creates orders from the cart ONLY
-- after a payment row with that reference is marked 'paid'. Stamps the order's
-- payment_status/payment_reference. Replaces direct unpaid checkout for the
-- Paystack flow (the old place_order_from_cart() is kept for fallback/testing).
--
-- Also adds an HTTP hook that pings the push Edge Function whenever a
-- notification row is inserted (best-effort; requires pg_net).
--
-- Run AFTER 0006/0007. Safe to run more than once.
-- ============================================================================

create or replace function public.place_order_from_cart_paid(p_reference text)
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

  -- The payment must exist, belong to this student, and be verified paid.
  if not exists (
    select 1 from public.payments
    where reference = p_reference
      and student_id = v_student
      and status = 'paid'
  ) then
    raise exception 'Payment not verified for reference %', p_reference;
  end if;

  -- Idempotency: if orders already exist for this reference, just return them.
  if exists (select 1 from public.orders where payment_reference = p_reference) then
    return query select order_id from public.orders where payment_reference = p_reference;
    return;
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
      raise exception 'Vendor % not available on your campus', r_vendor.vendor_id;
    end if;

    insert into public.orders
      (student_id, vendor_id, total_amount, order_status, payment_status, payment_reference)
    values (v_student, r_vendor.vendor_id, 0, 'pending', 'paid', p_reference)
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
    select v.user_id, 'New Order', 'You have received a new paid order.'
    from public.vendors v where v.vendor_id = r_vendor.vendor_id;

    return next v_order;
  end loop;

  delete from public.cart_items where cart_id = v_cart;
  return;
end;
$$;

-- ----------------------------------------------------------------------------
-- Push hook: when a notification is inserted, call the push Edge Function so
-- it can deliver an FCM message. Best-effort and non-blocking.
-- Requires the pg_net extension (available on Supabase) and two settings:
--   app.settings.push_function_url   -> https://<ref>.functions.supabase.co/send-push
--   app.settings.push_function_key   -> a shared secret you also set on the fn
-- If pg_net or settings are absent, the trigger silently does nothing.
-- ----------------------------------------------------------------------------
create extension if not exists pg_net;

create or replace function public.dispatch_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text;
  v_key text;
begin
  begin
    v_url := current_setting('app.settings.push_function_url', true);
    v_key := current_setting('app.settings.push_function_key', true);
  exception when others then
    return new;
  end;

  if v_url is null or v_url = '' then
    return new;  -- not configured; skip
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(v_key, '')
    ),
    body := jsonb_build_object(
      'recipient_id', new.recipient_id,
      'title', new.title,
      'body', new.body
    )
  );
  return new;
exception when others then
  return new;  -- never block the insert because of push failures
end;
$$;

drop trigger if exists trg_dispatch_push on public.notifications;
create trigger trg_dispatch_push
  after insert on public.notifications
  for each row execute function public.dispatch_push();
