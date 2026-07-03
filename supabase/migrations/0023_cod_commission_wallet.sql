-- Prepaid seller wallet for collecting commission on Cash on Delivery orders.

create table if not exists public.vendor_wallets (
  vendor_id uuid primary key references public.vendors(vendor_id) on delete cascade,
  available_pesewas integer not null default 0 check (available_pesewas >= 0),
  reserved_pesewas integer not null default 0 check (reserved_pesewas >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  transaction_id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(vendor_id) on delete cascade,
  order_id uuid references public.orders(order_id) on delete restrict,
  kind text not null check (kind in ('topup', 'reserve', 'capture', 'release', 'adjustment')),
  amount_pesewas integer not null check (amount_pesewas > 0),
  reference text unique,
  description text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.cod_commission_reservations (
  order_id uuid primary key references public.orders(order_id) on delete restrict,
  vendor_id uuid not null references public.vendors(vendor_id) on delete restrict,
  amount_pesewas integer not null check (amount_pesewas > 0),
  status text not null default 'reserved' check (status in ('reserved', 'captured', 'released')),
  created_at timestamptz not null default now(),
  settled_at timestamptz
);

create table if not exists public.wallet_topups (
  topup_id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(vendor_id) on delete cascade,
  amount_pesewas integer not null check (amount_pesewas >= 500),
  reference text not null unique,
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed')),
  created_at timestamptz not null default now(),
  verified_at timestamptz
);

alter table public.vendor_wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.cod_commission_reservations enable row level security;
alter table public.wallet_topups enable row level security;

create policy wallet_owner_read on public.vendor_wallets for select using (
  public.is_admin() or exists (
    select 1 from public.vendors v where v.vendor_id = vendor_wallets.vendor_id and v.user_id = auth.uid()
  )
);
create policy wallet_tx_owner_read on public.wallet_transactions for select using (
  public.is_admin() or exists (
    select 1 from public.vendors v where v.vendor_id = wallet_transactions.vendor_id and v.user_id = auth.uid()
  )
);
create policy cod_reservation_owner_read on public.cod_commission_reservations for select using (
  public.is_admin() or exists (
    select 1 from public.vendors v where v.vendor_id = cod_commission_reservations.vendor_id and v.user_id = auth.uid()
  )
);
create policy wallet_topup_owner_read on public.wallet_topups for select using (
  public.is_admin() or exists (
    select 1 from public.vendors v where v.vendor_id = wallet_topups.vendor_id and v.user_id = auth.uid()
  )
);

create or replace function public.manage_cod_commission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fee integer;
  v_campus uuid;
  v_balance integer;
  r_reservation record;
begin
  if new.payment_method <> 'cash_on_delivery' then return new; end if;

  if new.order_status = 'confirmed'
     and old.order_status is distinct from 'confirmed' then
    select campus_id into v_campus from public.vendors where vendor_id = new.vendor_id;
    v_fee := public.commission_for_price(round(new.total_amount * 100)::integer, v_campus);
    if v_fee <= 0 then return new; end if;

    insert into public.vendor_wallets (vendor_id) values (new.vendor_id)
    on conflict (vendor_id) do nothing;
    select available_pesewas into v_balance
      from public.vendor_wallets where vendor_id = new.vendor_id for update;
    if v_balance < v_fee then
      raise exception 'Insufficient COD commission balance. Add at least GH% to confirm this order.',
        to_char((v_fee - v_balance) / 100.0, 'FM999999990.00');
    end if;

    insert into public.cod_commission_reservations
      (order_id, vendor_id, amount_pesewas)
    values (new.order_id, new.vendor_id, v_fee)
    on conflict (order_id) do nothing;
    if found then
      update public.vendor_wallets
         set available_pesewas = available_pesewas - v_fee,
             reserved_pesewas = reserved_pesewas + v_fee,
             updated_at = now()
       where vendor_id = new.vendor_id;
      insert into public.wallet_transactions
        (vendor_id, order_id, kind, amount_pesewas, reference, description)
      values (new.vendor_id, new.order_id, 'reserve', v_fee,
        'reserve-' || new.order_id, 'COD commission reserved');
    end if;
  end if;

  if new.order_status in ('delivered', 'completed')
     and old.order_status not in ('delivered', 'completed') then
    select * into r_reservation from public.cod_commission_reservations
     where order_id = new.order_id and status = 'reserved' for update;
    if r_reservation is not null then
      update public.vendor_wallets
         set reserved_pesewas = reserved_pesewas - r_reservation.amount_pesewas,
             updated_at = now()
       where vendor_id = new.vendor_id;
      update public.cod_commission_reservations
         set status = 'captured', settled_at = now() where order_id = new.order_id;
      insert into public.wallet_transactions
        (vendor_id, order_id, kind, amount_pesewas, reference, description)
      values (new.vendor_id, new.order_id, 'capture', r_reservation.amount_pesewas,
        'capture-' || new.order_id, 'COD commission paid to platform');
    end if;
  elsif new.order_status = 'cancelled' and old.order_status <> 'cancelled' then
    select * into r_reservation from public.cod_commission_reservations
     where order_id = new.order_id and status = 'reserved' for update;
    if r_reservation is not null then
      update public.vendor_wallets
         set available_pesewas = available_pesewas + r_reservation.amount_pesewas,
             reserved_pesewas = reserved_pesewas - r_reservation.amount_pesewas,
             updated_at = now()
       where vendor_id = new.vendor_id;
      update public.cod_commission_reservations
         set status = 'released', settled_at = now() where order_id = new.order_id;
      insert into public.wallet_transactions
        (vendor_id, order_id, kind, amount_pesewas, reference, description)
      values (new.vendor_id, new.order_id, 'release', r_reservation.amount_pesewas,
        'release-' || new.order_id, 'Cancelled order commission released');
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_manage_cod_commission on public.orders;
create trigger trg_manage_cod_commission
after update of order_status on public.orders
for each row execute function public.manage_cod_commission();

create or replace function public.credit_wallet_topup(p_reference text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare r_topup record;
begin
  select * into r_topup from public.wallet_topups
   where reference = p_reference for update;
  if r_topup is null then raise exception 'Top-up not found'; end if;
  if r_topup.status = 'paid' then return; end if;

  update public.wallet_topups
     set status = 'paid', verified_at = now()
   where topup_id = r_topup.topup_id;
  insert into public.vendor_wallets (vendor_id, available_pesewas)
  values (r_topup.vendor_id, r_topup.amount_pesewas)
  on conflict (vendor_id) do update
    set available_pesewas = vendor_wallets.available_pesewas + excluded.available_pesewas,
        updated_at = now();
  insert into public.wallet_transactions
    (vendor_id, kind, amount_pesewas, reference, description)
  values (r_topup.vendor_id, 'topup', r_topup.amount_pesewas,
          p_reference, 'COD commission wallet top-up');
end;
$$;

revoke all on function public.credit_wallet_topup(text) from public, anon, authenticated;
grant execute on function public.credit_wallet_topup(text) to service_role;
