-- Buyer token redemption funded exclusively from UjustBUY's commission.
-- 1 token = 20 pesewas. Seller proceeds are never reduced.

alter table public.orders
  add column if not exists token_discount_pesewas integer not null default 0
    check (token_discount_pesewas >= 0),
  add column if not exists tokens_redeemed integer not null default 0
    check (tokens_redeemed >= 0);

create or replace function public.checkout_token_quote()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_commission integer := 0;
  v_balance integer := public.token_balance(auth.uid());
  r record;
begin
  for r in
    select p.vendor_id, round(sum(p.price * ci.quantity) * 100)::integer gross,
           v.campus_id
    from public.carts c
    join public.cart_items ci on ci.cart_id = c.cart_id
    join public.products p on p.product_id = ci.product_id
    join public.vendors v on v.vendor_id = p.vendor_id
    where c.student_id = auth.uid()
    group by p.vendor_id, v.campus_id
  loop
    v_commission := v_commission
      + least(r.gross, public.commission_for_price(r.gross, r.campus_id));
  end loop;

  return jsonb_build_object(
    'balance', v_balance,
    'commission_pesewas', v_commission,
    'tokens_to_redeem', least(v_balance, floor(v_commission / 20.0)::integer),
    'discount_pesewas', least(floor(v_commission / 20.0)::integer * 20,
                               v_balance * 20)
  );
end;
$$;

create or replace function public.apply_checkout_token_discount(p_orders uuid[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance integer := public.token_balance(auth.uid());
  v_remaining integer;
  v_total_discount integer := 0;
  v_tokens integer;
  r record;
  v_fee integer;
  v_discount integer;
begin
  select least(v_balance * 20, coalesce(sum(
    least(round(o.total_amount * 100)::integer,
      public.commission_for_price(round(o.total_amount * 100)::integer, v.campus_id))
  ), 0))::integer
  into v_remaining
  from public.orders o join public.vendors v on v.vendor_id = o.vendor_id
  where o.order_id = any(p_orders) and o.student_id = auth.uid();

  -- Whole tokens only; never debit a token for an unusable fraction.
  v_remaining := floor(v_remaining / 20.0)::integer * 20;
  for r in
    select o.order_id, o.total_amount, v.campus_id
    from public.orders o join public.vendors v on v.vendor_id = o.vendor_id
    where o.order_id = any(p_orders) and o.student_id = auth.uid()
    order by o.created_at, o.order_id
  loop
    exit when v_remaining <= 0;
    v_fee := least(round(r.total_amount * 100)::integer,
      public.commission_for_price(round(r.total_amount * 100)::integer, r.campus_id));
    v_discount := least(floor(v_fee / 20.0)::integer * 20, v_remaining);
    update public.orders set
      token_discount_pesewas = v_discount,
      tokens_redeemed = floor(v_discount / 20.0)::integer
    where order_id = r.order_id;
    v_remaining := v_remaining - v_discount;
    v_total_discount := v_total_discount + v_discount;
  end loop;

  v_tokens := floor(v_total_discount / 20.0)::integer;
  if v_tokens > 0 then
    perform public._award_tokens(auth.uid(), -v_tokens,
      'Checkout commission discount');
  end if;
  return jsonb_build_object('tokens_redeemed', v_tokens,
    'discount_pesewas', v_total_discount);
end;
$$;

-- Existing checkout functions originally restricted purchases to role=student.
-- Student Sellers retain buyer capability, so widen that guard in-place.
do $$
declare d text;
begin
  select pg_get_functiondef('public.place_order_checkout(text,text,text,text)'::regprocedure) into d;
  d := replace(d, 'public.current_role() <> ''student''',
                   'public.current_role() not in (''student'', ''vendor'')');
  execute d;
  select pg_get_functiondef('public.place_order_checkout_paid(text,text,text,text)'::regprocedure) into d;
  d := replace(d, 'public.current_role() <> ''student''',
                   'public.current_role() not in (''student'', ''vendor'')');
  execute d;
end $$;

-- COD sellers collect the discounted cash total from the buyer, then pay only
-- the remaining platform commission from their wallet. Their net is unchanged.
do $$
declare d text;
begin
  select pg_get_functiondef('public.manage_cod_commission()'::regprocedure) into d;
  d := replace(d,
    'v_fee := public.commission_for_price(round(new.total_amount * 100)::integer, v_campus);',
    'v_fee := greatest(0, public.commission_for_price(round(new.total_amount * 100)::integer, v_campus) - new.token_discount_pesewas);');
  execute d;
end $$;

-- Settlement keeps the seller's original net; only the platform fee is reduced.
create or replace function public.settle_completed_order()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_gross integer; v_normal_fee integer; v_platform_fee integer;
  v_net integer; v_campus uuid; v_momo text; v_network text; v_settlement uuid;
begin
  if new.order_status <> 'completed' or old.order_status = 'completed'
     or new.payment_status <> 'paid' then return new; end if;
  select campus_id, momo_number, momo_network into v_campus, v_momo, v_network
    from public.vendors where vendor_id = new.vendor_id;
  if nullif(trim(v_momo), '') is null or nullif(trim(v_network), '') is null then
    raise exception 'Seller payout details are incomplete'; end if;
  v_gross := round(new.total_amount * 100)::integer;
  v_normal_fee := least(v_gross, public.commission_for_price(v_gross, v_campus));
  v_platform_fee := greatest(0, v_normal_fee - new.token_discount_pesewas);
  v_net := v_gross - v_normal_fee;
  insert into public.order_settlements
    (order_id,vendor_id,gross_pesewas,platform_fee_pesewas,seller_net_pesewas)
  values (new.order_id,new.vendor_id,v_gross,v_platform_fee,v_net)
  on conflict (order_id) do nothing returning settlement_id into v_settlement;
  if v_settlement is not null and v_net > 0 then
    insert into public.payout_jobs
      (settlement_id,vendor_id,amount_pesewas,momo_number,momo_network,provider_reference)
    values (v_settlement,new.vendor_id,v_net,trim(v_momo),trim(v_network),
      'reparto-' || replace(new.order_id::text,'-',''));
  end if; return new;
end $$;

revoke all on function public.checkout_token_quote() from public;
revoke all on function public.apply_checkout_token_discount(uuid[]) from public;
grant execute on function public.checkout_token_quote() to authenticated;
grant execute on function public.apply_checkout_token_discount(uuid[]) to authenticated;
