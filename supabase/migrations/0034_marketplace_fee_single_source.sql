-- Replace legacy tier commission with the percentage configured in Platform Settings.

create or replace function public.marketplace_fee_for_amount(
  p_amount_pesewas integer,
  p_is_service boolean default false
) returns integer
language sql
stable
security definer
set search_path = public
as $$
  select greatest(0, least(p_amount_pesewas, round(
    p_amount_pesewas * coalesce(
      case when p_is_service then platform_fee_service_percent
           else platform_fee_seller_percent end, 0
    ) / 100.0
  )::integer))
  from public.platform_settings
  order by updated_at desc
  limit 1
$$;

create or replace function public.checkout_token_quote()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_fee integer := 0; v_balance integer := public.token_balance(auth.uid()); r record;
begin
  for r in select round(sum(p.price * ci.quantity) * 100)::integer gross
    from public.carts c join public.cart_items ci on ci.cart_id = c.cart_id
    join public.products p on p.product_id = ci.product_id
    where c.student_id = auth.uid() group by p.vendor_id
  loop v_fee := v_fee + public.marketplace_fee_for_amount(r.gross); end loop;
  return jsonb_build_object('balance',v_balance,'commission_pesewas',v_fee,
    'tokens_to_redeem',least(v_balance,floor(v_fee/20.0)::integer),
    'discount_pesewas',least(floor(v_fee/20.0)::integer*20,v_balance*20));
end $$;

create or replace function public.apply_checkout_token_discount(p_orders uuid[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_balance integer := public.token_balance(auth.uid()); v_remaining integer;
  v_total_discount integer := 0; v_tokens integer; r record; v_fee integer; v_discount integer;
begin
  select least(v_balance*20,coalesce(sum(public.marketplace_fee_for_amount(
    round(o.total_amount*100)::integer)),0))::integer into v_remaining
  from public.orders o where o.order_id=any(p_orders) and o.student_id=auth.uid();
  v_remaining := floor(v_remaining/20.0)::integer*20;
  for r in select o.order_id,o.total_amount from public.orders o
    where o.order_id=any(p_orders) and o.student_id=auth.uid() order by o.created_at,o.order_id
  loop
    exit when v_remaining<=0;
    v_fee := public.marketplace_fee_for_amount(round(r.total_amount*100)::integer);
    v_discount := least(floor(v_fee/20.0)::integer*20,v_remaining);
    update public.orders set token_discount_pesewas=v_discount,
      tokens_redeemed=floor(v_discount/20.0)::integer where order_id=r.order_id;
    v_remaining:=v_remaining-v_discount; v_total_discount:=v_total_discount+v_discount;
  end loop;
  v_tokens:=floor(v_total_discount/20.0)::integer;
  if v_tokens>0 then perform public._award_tokens(auth.uid(),-v_tokens,'Checkout marketplace fee discount'); end if;
  return jsonb_build_object('tokens_redeemed',v_tokens,'discount_pesewas',v_total_discount);
end $$;

create or replace function public.manage_cod_commission()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_fee integer; v_balance integer; r_reservation record;
begin
  if new.payment_method<>'cash_on_delivery' then return new; end if;
  if new.order_status='confirmed' and old.order_status is distinct from 'confirmed' then
    v_fee:=greatest(0,public.marketplace_fee_for_amount(round(new.total_amount*100)::integer)-new.token_discount_pesewas);
    if v_fee<=0 then return new; end if;
    insert into public.vendor_wallets(vendor_id) values(new.vendor_id) on conflict(vendor_id) do nothing;
    select available_pesewas into v_balance from public.vendor_wallets where vendor_id=new.vendor_id for update;
    if v_balance<v_fee then raise exception 'Insufficient marketplace fee balance. Add at least GH% to confirm this order.',to_char((v_fee-v_balance)/100.0,'FM999999990.00'); end if;
    insert into public.cod_commission_reservations(order_id,vendor_id,amount_pesewas)
      values(new.order_id,new.vendor_id,v_fee) on conflict(order_id) do nothing;
    if found then
      update public.vendor_wallets set available_pesewas=available_pesewas-v_fee,
        reserved_pesewas=reserved_pesewas+v_fee,updated_at=now() where vendor_id=new.vendor_id;
      insert into public.wallet_transactions(vendor_id,order_id,kind,amount_pesewas,reference,description)
        values(new.vendor_id,new.order_id,'reserve',v_fee,'reserve-'||new.order_id,'COD marketplace fee reserved');
    end if;
  end if;
  if new.order_status in ('delivered','completed') and old.order_status not in ('delivered','completed') then
    select * into r_reservation from public.cod_commission_reservations where order_id=new.order_id and status='reserved' for update;
    if r_reservation is not null then
      update public.vendor_wallets set reserved_pesewas=reserved_pesewas-r_reservation.amount_pesewas,updated_at=now() where vendor_id=new.vendor_id;
      update public.cod_commission_reservations set status='captured',settled_at=now() where order_id=new.order_id;
      insert into public.wallet_transactions(vendor_id,order_id,kind,amount_pesewas,reference,description)
        values(new.vendor_id,new.order_id,'capture',r_reservation.amount_pesewas,'capture-'||new.order_id,'COD marketplace fee paid');
    end if;
  elsif new.order_status='cancelled' and old.order_status<>'cancelled' then
    select * into r_reservation from public.cod_commission_reservations where order_id=new.order_id and status='reserved' for update;
    if r_reservation is not null then
      update public.vendor_wallets set available_pesewas=available_pesewas+r_reservation.amount_pesewas,
        reserved_pesewas=reserved_pesewas-r_reservation.amount_pesewas,updated_at=now() where vendor_id=new.vendor_id;
      update public.cod_commission_reservations set status='released',settled_at=now() where order_id=new.order_id;
      insert into public.wallet_transactions(vendor_id,order_id,kind,amount_pesewas,reference,description)
        values(new.vendor_id,new.order_id,'release',r_reservation.amount_pesewas,'release-'||new.order_id,'Cancelled order marketplace fee released');
    end if;
  end if; return new;
end $$;

create or replace function public.settle_completed_order()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_gross integer; v_normal_fee integer; v_platform_fee integer; v_net integer;
  v_momo text; v_network text; v_settlement uuid;
begin
  if new.order_status<>'completed' or old.order_status='completed' or new.payment_status<>'paid' then return new; end if;
  select momo_number,momo_network into v_momo,v_network from public.vendors where vendor_id=new.vendor_id;
  if nullif(trim(v_momo),'') is null or nullif(trim(v_network),'') is null then raise exception 'Seller payout details are incomplete'; end if;
  v_gross:=round(new.total_amount*100)::integer;
  v_normal_fee:=public.marketplace_fee_for_amount(v_gross);
  v_platform_fee:=greatest(0,v_normal_fee-new.token_discount_pesewas);
  v_net:=v_gross-v_normal_fee;
  insert into public.order_settlements(order_id,vendor_id,gross_pesewas,platform_fee_pesewas,seller_net_pesewas)
    values(new.order_id,new.vendor_id,v_gross,v_platform_fee,v_net) on conflict(order_id) do nothing returning settlement_id into v_settlement;
  if v_settlement is not null and v_net>0 then
    insert into public.payout_jobs(settlement_id,vendor_id,amount_pesewas,momo_number,momo_network,provider_reference)
      values(v_settlement,new.vendor_id,v_net,trim(v_momo),trim(v_network),'reparto-'||replace(new.order_id::text,'-',''));
  end if; return new;
end $$;

drop function if exists public.commission_for_price(integer,uuid);
drop table if exists public.commission_tiers;
drop function if exists public.redeem_commission_discount(uuid);
alter table public.products drop column if exists commission_waived;

revoke all on function public.marketplace_fee_for_amount(integer,boolean) from public;
grant execute on function public.marketplace_fee_for_amount(integer,boolean) to anon,authenticated;
