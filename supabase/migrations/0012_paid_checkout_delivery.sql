-- ============================================================================
-- Reparto :: Migration 0012 :: Paid checkout with delivery details
-- ----------------------------------------------------------------------------
-- place_order_checkout_paid(...) combines the verified-payment guard of
-- place_order_from_cart_paid with the delivery-detail capture of
-- place_order_checkout. The Edge Function (paystack-verify) calls this so that
-- card/online orders also carry delivery address, contact phone and note.
--
-- Run AFTER 0011. Safe to run more than once.
-- ============================================================================

create or replace function public.place_order_checkout_paid(
  p_reference        text,
  p_delivery_address text,
  p_contact_phone    text,
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

  -- Payment must exist, belong to this student, and be verified paid.
  if not exists (
    select 1 from public.payments
    where reference = p_reference
      and student_id = v_student
      and status = 'paid'
  ) then
    raise exception 'Payment not verified for reference %', p_reference;
  end if;

  -- Idempotency: return existing orders for this reference.
  if exists (select 1 from public.orders where payment_reference = p_reference) then
    return query select order_id from public.orders where payment_reference = p_reference;
    return;
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
      (student_id, vendor_id, total_amount, order_status, payment_status,
       payment_reference, delivery_address, contact_phone, payment_method, note)
    values
      (v_student, r_vendor.vendor_id, 0, 'pending', 'paid',
       p_reference, p_delivery_address, p_contact_phone, 'momo', p_note)
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
