-- Atomic, idempotent settlement accounting for prepaid completed orders.

create table if not exists public.order_settlements (
  settlement_id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(order_id) on delete restrict,
  vendor_id uuid not null references public.vendors(vendor_id) on delete restrict,
  gross_pesewas integer not null check (gross_pesewas >= 0),
  platform_fee_pesewas integer not null check (platform_fee_pesewas >= 0),
  seller_net_pesewas integer not null check (seller_net_pesewas >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.payout_jobs (
  payout_id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null unique references public.order_settlements(settlement_id) on delete restrict,
  vendor_id uuid not null references public.vendors(vendor_id) on delete restrict,
  amount_pesewas integer not null check (amount_pesewas > 0),
  momo_number text not null,
  momo_network text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'submitted', 'success', 'failed', 'reversed')),
  provider_reference text not null unique,
  provider_transfer_code text,
  failure_reason text,
  attempt_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.order_settlements enable row level security;
alter table public.payout_jobs enable row level security;

create policy settlement_vendor_read on public.order_settlements
for select using (
  public.is_admin() or exists (
    select 1 from public.vendors v
    where v.vendor_id = order_settlements.vendor_id and v.user_id = auth.uid()
  )
);

create policy payout_vendor_read on public.payout_jobs
for select using (
  public.is_admin() or exists (
    select 1 from public.vendors v
    where v.vendor_id = payout_jobs.vendor_id and v.user_id = auth.uid()
  )
);

create or replace function public.settle_completed_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gross integer;
  v_fee integer;
  v_net integer;
  v_campus uuid;
  v_momo text;
  v_network text;
  v_settlement uuid;
begin
  if new.order_status <> 'completed'
     or old.order_status = 'completed'
     or new.payment_status <> 'paid' then
    return new;
  end if;

  select campus_id, momo_number, momo_network
    into v_campus, v_momo, v_network
    from public.vendors where vendor_id = new.vendor_id;

  if nullif(trim(v_momo), '') is null or nullif(trim(v_network), '') is null then
    raise exception 'Seller payout details are incomplete';
  end if;

  v_gross := round(new.total_amount * 100)::integer;
  v_fee := least(v_gross, public.commission_for_price(v_gross, v_campus));
  v_net := v_gross - v_fee;

  insert into public.order_settlements
    (order_id, vendor_id, gross_pesewas, platform_fee_pesewas, seller_net_pesewas)
  values (new.order_id, new.vendor_id, v_gross, v_fee, v_net)
  on conflict (order_id) do nothing
  returning settlement_id into v_settlement;

  if v_settlement is not null and v_net > 0 then
    insert into public.payout_jobs
      (settlement_id, vendor_id, amount_pesewas, momo_number, momo_network,
       provider_reference)
    values
      (v_settlement, new.vendor_id, v_net, trim(v_momo), trim(v_network),
       'reparto-' || replace(new.order_id::text, '-', ''));
  end if;

  return new;
end;
$$;

drop trigger if exists trg_settle_completed_order on public.orders;
create trigger trg_settle_completed_order
after update of order_status on public.orders
for each row execute function public.settle_completed_order();

comment on column public.order_settlements.platform_fee_pesewas is
  'Admin/platform share retained in the Paystack business balance.';
