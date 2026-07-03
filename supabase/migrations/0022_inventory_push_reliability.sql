-- Live inventory updates and observable remote-push dispatch.

do $$
begin
  begin
    alter publication supabase_realtime add table public.products;
  exception when duplicate_object then null;
  end;
end $$;
alter table public.products replica identity full;

create or replace function public.restock_cancelled_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.order_status = 'cancelled'
     and old.order_status is distinct from 'cancelled' then
    update public.products p
       set quantity_available = p.quantity_available + oi.quantity
      from public.order_items oi
     where oi.order_id = new.order_id
       and oi.product_id = p.product_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restock_cancelled_order on public.orders;
create trigger trg_restock_cancelled_order
after update of order_status on public.orders
for each row execute function public.restock_cancelled_order();

create table if not exists public.push_dispatch_config (
  id boolean primary key default true check (id),
  function_url text not null,
  function_secret text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.push_dispatch_log (
  dispatch_id bigint generated always as identity primary key,
  notification_id uuid,
  recipient_id uuid not null,
  request_id bigint,
  status text not null,
  detail text,
  created_at timestamptz not null default now()
);

alter table public.push_dispatch_config enable row level security;
alter table public.push_dispatch_log enable row level security;

create policy push_config_admin on public.push_dispatch_config
for all using (public.is_admin()) with check (public.is_admin());
create policy push_log_admin on public.push_dispatch_log
for select using (public.is_admin());

create or replace function public.dispatch_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_config record;
  v_request_id bigint;
begin
  select * into v_config
    from public.push_dispatch_config
   where id = true and enabled = true;

  if v_config is null then
    insert into public.push_dispatch_log
      (notification_id, recipient_id, status, detail)
    values
      (new.notification_id, new.recipient_id, 'not_configured',
       'Configure push_dispatch_config with the send-push URL and shared secret');
    return new;
  end if;

  select net.http_post(
    url := v_config.function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_config.function_secret
    ),
    body := jsonb_build_object(
      'recipient_id', new.recipient_id,
      'title', new.title,
      'body', new.body
    )
  ) into v_request_id;

  insert into public.push_dispatch_log
    (notification_id, recipient_id, request_id, status)
  values (new.notification_id, new.recipient_id, v_request_id, 'queued');
  return new;
exception when others then
  insert into public.push_dispatch_log
    (notification_id, recipient_id, status, detail)
  values (new.notification_id, new.recipient_id, 'error', sqlerrm);
  return new;
end;
$$;
