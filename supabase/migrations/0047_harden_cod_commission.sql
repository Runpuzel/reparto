-- COD commission must fail closed. A missing platform_settings row previously
-- made marketplace_fee_for_amount() return null, which allowed a zero-balance
-- seller to confirm an order without reserving the platform fee.

insert into public.platform_settings (
  service_auth_fee,
  service_auth_duration_days,
  service_free_listing_days,
  platform_fee_seller_percent,
  platform_fee_service_percent,
  verification_required_for_prepayment,
  kyc_allowed_types,
  current_policy_version
)
select
  0,
  30,
  14,
  5.00,
  8.00,
  true,
  array['ghana_card', 'student_id']::text[],
  'v1.0-2025-07'
where not exists (select 1 from public.platform_settings);

create or replace function public.marketplace_fee_for_amount(
  p_amount_pesewas integer,
  p_is_service boolean default false
) returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rate numeric;
begin
  if p_amount_pesewas < 0 then
    raise exception 'Marketplace fee amount cannot be negative';
  end if;

  select case
    when p_is_service then platform_fee_service_percent
    else platform_fee_seller_percent
  end
  into v_rate
  from public.platform_settings
  order by updated_at desc
  limit 1;

  if v_rate is null then
    raise exception 'Marketplace fee settings are unavailable. Contact support before confirming this order.';
  end if;
  if v_rate < 0 or v_rate > 100 then
    raise exception 'Marketplace fee settings are invalid. Contact support before confirming this order.';
  end if;

  return greatest(
    0,
    least(p_amount_pesewas, round(p_amount_pesewas * v_rate / 100.0)::integer)
  );
end;
$$;

revoke all on function public.marketplace_fee_for_amount(integer, boolean)
from public;
grant execute on function public.marketplace_fee_for_amount(integer, boolean)
to anon, authenticated;

-- Buyers and sellers only need to update order_status directly. Sensitive fee
-- and payment columns remain writable by trusted security-definer functions
-- and the service role, preventing a client from manufacturing a discount or
-- changing COD to another payment method before confirmation.
revoke update on table public.orders from public, anon, authenticated;
grant update (order_status) on table public.orders to authenticated;
grant all on table public.orders to service_role;

create or replace function public.enforce_order_payment_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_vendor boolean := false;
begin
  if new.payment_method is distinct from old.payment_method then
    raise exception 'Order payment method cannot be changed after creation';
  end if;

  if auth.uid() = old.student_id
     and not public.is_admin()
     and new.order_status is distinct from old.order_status
     and not (
       (old.order_status = 'pending' and new.order_status = 'cancelled'
        and old.payment_status <> 'paid')
       or (old.order_status = 'delivered' and new.order_status = 'completed')
       or new.order_status = 'disputed'
     ) then
    raise exception 'This order status change is not available to the buyer';
  end if;

  select exists (
    select 1
    from public.vendors v
    where v.vendor_id = old.vendor_id and v.user_id = auth.uid()
  ) into v_is_vendor;

  if v_is_vendor
     and not public.is_admin()
     and new.order_status is distinct from old.order_status
     and not (
       (old.order_status::text = 'pending'
        and new.order_status::text in ('confirmed', 'cancelled'))
       or (old.order_status::text = 'confirmed'
           and new.order_status::text in ('dispatched', 'cancelled'))
       or (old.order_status::text = 'dispatched'
           and new.order_status::text = 'delivered')
       or (old.order_status::text = 'accepted'
           and new.order_status::text in ('dispatched', 'cancelled'))
       or (old.order_status::text = 'preparing'
           and new.order_status::text = 'dispatched')
       or (old.order_status::text = 'ready_for_pickup'
           and new.order_status::text = 'delivered')
     ) then
    raise exception 'Orders must follow the required confirmation and delivery steps';
  end if;

  if old.payment_status = 'paid'
     and new.payment_status is distinct from old.payment_status then
    raise exception 'A verified payment cannot be changed or reversed directly';
  end if;
  if old.payment_status = 'paid'
     and old.payment_method <> 'cash_on_delivery'
     and new.order_status = 'cancelled'
     and old.order_status is distinct from 'cancelled' then
    raise exception 'Paid Mobile Money orders cannot be cancelled; open a dispute instead';
  end if;
  if new.student_id is distinct from old.student_id
     or new.vendor_id is distinct from old.vendor_id then
    raise exception 'Order buyer and seller cannot be changed';
  end if;
  if old.payment_reference is not null
     and new.payment_reference is distinct from old.payment_reference then
    raise exception 'Payment reference cannot be changed';
  end if;
  if old.total_amount > 0
     and new.total_amount is distinct from old.total_amount then
    raise exception 'Order total cannot be changed after creation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_order_payment_integrity on public.orders;
create trigger trg_enforce_order_payment_integrity
before update on public.orders
for each row execute function public.enforce_order_payment_integrity();

create or replace function public.manage_cod_commission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fee integer;
  v_balance integer;
  r_reservation record;
begin
  if old.payment_method <> 'cash_on_delivery' then
    return new;
  end if;

  if new.order_status = 'confirmed'
     and old.order_status is distinct from 'confirmed' then
    v_fee := greatest(
      0,
      public.marketplace_fee_for_amount(round(new.total_amount * 100)::integer)
        - coalesce(old.token_discount_pesewas, 0)
    );

    if v_fee <= 0 then
      return new;
    end if;

    insert into public.vendor_wallets (vendor_id)
    values (new.vendor_id)
    on conflict (vendor_id) do nothing;

    select available_pesewas
    into v_balance
    from public.vendor_wallets
    where vendor_id = new.vendor_id
    for update;

    if coalesce(v_balance, 0) < v_fee then
      raise exception 'Insufficient marketplace fee balance. Add at least GH% to confirm this order.',
        to_char((v_fee - coalesce(v_balance, 0)) / 100.0, 'FM999999990.00');
    end if;

    insert into public.cod_commission_reservations (
      order_id,
      vendor_id,
      amount_pesewas
    ) values (
      new.order_id,
      new.vendor_id,
      v_fee
    ) on conflict (order_id) do nothing;

    if found then
      update public.vendor_wallets
      set available_pesewas = available_pesewas - v_fee,
          reserved_pesewas = reserved_pesewas + v_fee,
          updated_at = now()
      where vendor_id = new.vendor_id;

      insert into public.wallet_transactions (
        vendor_id,
        order_id,
        kind,
        amount_pesewas,
        reference,
        description
      ) values (
        new.vendor_id,
        new.order_id,
        'reserve',
        v_fee,
        'reserve-' || new.order_id,
        'COD marketplace fee reserved'
      );
    end if;
  end if;

  if new.order_status in ('delivered', 'completed')
     and old.order_status not in ('delivered', 'completed') then
    select *
    into r_reservation
    from public.cod_commission_reservations
    where order_id = new.order_id and status = 'reserved'
    for update;

    if r_reservation is not null then
      update public.vendor_wallets
      set reserved_pesewas = reserved_pesewas - r_reservation.amount_pesewas,
          updated_at = now()
      where vendor_id = new.vendor_id;

      update public.cod_commission_reservations
      set status = 'captured', settled_at = now()
      where order_id = new.order_id;

      insert into public.wallet_transactions (
        vendor_id,
        order_id,
        kind,
        amount_pesewas,
        reference,
        description
      ) values (
        new.vendor_id,
        new.order_id,
        'capture',
        r_reservation.amount_pesewas,
        'capture-' || new.order_id,
        'COD marketplace fee paid'
      );
    end if;
  elsif new.order_status = 'cancelled'
        and old.order_status <> 'cancelled' then
    select *
    into r_reservation
    from public.cod_commission_reservations
    where order_id = new.order_id and status = 'reserved'
    for update;

    if r_reservation is not null then
      update public.vendor_wallets
      set available_pesewas = available_pesewas + r_reservation.amount_pesewas,
          reserved_pesewas = reserved_pesewas - r_reservation.amount_pesewas,
          updated_at = now()
      where vendor_id = new.vendor_id;

      update public.cod_commission_reservations
      set status = 'released', settled_at = now()
      where order_id = new.order_id;

      insert into public.wallet_transactions (
        vendor_id,
        order_id,
        kind,
        amount_pesewas,
        reference,
        description
      ) values (
        new.vendor_id,
        new.order_id,
        'release',
        r_reservation.amount_pesewas,
        'release-' || new.order_id,
        'Cancelled order marketplace fee released'
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_manage_cod_commission on public.orders;
create trigger trg_manage_cod_commission
before update of order_status on public.orders
for each row execute function public.manage_cod_commission();
