-- Keep sellers without payout details on Cash on Delivery while preserving
-- the payout destination that was approved when online payment began.

create or replace function public.is_valid_momo_payout(
  p_number text,
  p_network text
)
returns boolean
language sql
immutable
parallel safe
as $$
  select regexp_replace(coalesce(p_number, ''), '[^0-9]', '', 'g')
           ~ '^0[0-9]{9}$'
    and lower(regexp_replace(coalesce(p_network, ''), '[^a-zA-Z]', '', 'g'))
        in ('mtn', 'vodafone', 'telecel', 'airteltigo');
$$;

create or replace function public.stamp_vendor_momo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_metadata jsonb;
  v_snapshot jsonb;
  v_momo text;
  v_network text;
  v_identity_ready boolean := false;
  v_verification_required boolean := true;
begin
  -- COD is always available. Stamp any existing details for the order record,
  -- but do not require them.
  if new.payment_method::text = 'cash_on_delivery' then
    if new.vendor_momo_number is null then
      select momo_number, momo_network
        into new.vendor_momo_number, new.vendor_momo_network
      from public.vendors
      where vendor_id = new.vendor_id;
    end if;
    return new;
  end if;

  if new.payment_status <> 'paid' or new.payment_reference is null then
    raise exception 'Online orders require a verified payment';
  end if;

  select metadata
    into v_metadata
  from public.payments
  where reference = new.payment_reference
    and student_id = new.student_id
    and status = 'paid';

  if v_metadata is null then
    raise exception 'Payment not verified for this order';
  end if;

  v_snapshot := v_metadata -> 'vendor_payouts' -> new.vendor_id::text;
  v_momo := v_snapshot ->> 'momo_number';
  v_network := v_snapshot ->> 'momo_network';
  v_identity_ready := coalesce(
    (v_snapshot ->> 'identity_verified')::boolean,
    false
  );

  -- Pending payments created before this migration have no snapshot. Permit
  -- them only when the seller is currently fully eligible.
  if not public.is_valid_momo_payout(v_momo, v_network) then
    select momo_number, momo_network,
           is_verified and verification_status = 'approved'
      into v_momo, v_network, v_identity_ready
    from public.vendors
    where vendor_id = new.vendor_id;

    select coalesce(verification_required_for_prepayment, true)
      into v_verification_required
    from public.platform_settings
    order by updated_at desc
    limit 1;

    if not v_verification_required then
      v_identity_ready := true;
    end if;
  end if;

  if not public.is_valid_momo_payout(v_momo, v_network) then
    raise exception 'Seller payout details are incomplete; use Cash on Delivery';
  end if;
  if not v_identity_ready then
    raise exception 'Seller identity verification is incomplete; use Cash on Delivery';
  end if;

  new.vendor_momo_number := regexp_replace(v_momo, '[^0-9]', '', 'g');
  new.vendor_momo_network := trim(v_network);
  return new;
end;
$$;

comment on function public.stamp_vendor_momo() is
  'Allows COD without payout details and requires a trusted payout snapshot for prepaid orders.';

-- Release prepaid proceeds using the payout destination stamped on the order,
-- rather than mutable seller profile details.
create or replace function public.settle_completed_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gross integer;
  v_normal_fee integer;
  v_platform_fee integer;
  v_net integer;
  v_momo text;
  v_network text;
  v_settlement uuid;
begin
  if new.order_status <> 'completed'
     or old.order_status = 'completed'
     or new.payment_status <> 'paid' then
    return new;
  end if;

  v_momo := new.vendor_momo_number;
  v_network := new.vendor_momo_network;
  if not public.is_valid_momo_payout(v_momo, v_network) then
    raise exception 'Seller payout details are incomplete';
  end if;

  v_gross := round(new.total_amount * 100)::integer;
  v_normal_fee := public.marketplace_fee_for_amount(v_gross);
  v_platform_fee := greatest(0, v_normal_fee - new.token_discount_pesewas);
  v_net := v_gross - v_normal_fee;

  insert into public.order_settlements(
    order_id,
    vendor_id,
    gross_pesewas,
    platform_fee_pesewas,
    seller_net_pesewas
  ) values (
    new.order_id,
    new.vendor_id,
    v_gross,
    v_platform_fee,
    v_net
  )
  on conflict(order_id) do nothing
  returning settlement_id into v_settlement;

  if v_settlement is not null and v_net > 0 then
    insert into public.payout_jobs(
      settlement_id,
      vendor_id,
      amount_pesewas,
      momo_number,
      momo_network,
      provider_reference
    ) values (
      v_settlement,
      new.vendor_id,
      v_net,
      regexp_replace(v_momo, '[^0-9]', '', 'g'),
      trim(v_network),
      'reparto-' || replace(new.order_id::text, '-', '')
    );
  end if;

  return new;
end;
$$;
