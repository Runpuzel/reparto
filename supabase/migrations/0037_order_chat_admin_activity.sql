-- Private, order-bound messaging and aggregate admin marketplace activity.

create table if not exists public.order_messages (
  message_id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(order_id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists idx_order_messages_order_time
  on public.order_messages(order_id, created_at);
alter table public.order_messages enable row level security;

create or replace function public.can_access_order_chat(p_order uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_admin() or exists (
    select 1 from public.orders o
    left join public.vendors v on v.vendor_id=o.vendor_id
    where o.order_id=p_order and (o.student_id=auth.uid() or v.user_id=auth.uid())
  )
$$;

drop policy if exists order_messages_participant_read on public.order_messages;
create policy order_messages_participant_read on public.order_messages for select
  using (public.can_access_order_chat(order_id));
drop policy if exists order_messages_participant_insert on public.order_messages;
create policy order_messages_participant_insert on public.order_messages for insert
  with check (sender_id=auth.uid() and public.can_access_order_chat(order_id));

create or replace function public.protect_order_chat_contact_details()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.body ~* '([[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|https?://|www\.|(\+?233|0)[ -]?[235][0-9][ -]?[0-9]{3}[ -]?[0-9]{4})' then
    raise exception 'For your safety, phone numbers, email addresses and links cannot be shared in order chat.';
  end if;
  return new;
end $$;
drop trigger if exists trg_protect_order_chat_contact_details on public.order_messages;
create trigger trg_protect_order_chat_contact_details before insert or update on public.order_messages
for each row execute function public.protect_order_chat_contact_details();

create or replace function public.admin_marketplace_activity()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;
  select jsonb_build_object(
    'total_orders',(select count(*) from orders),
    'completed_orders',(select count(*) from orders where order_status in ('completed','delivered')),
    'cancelled_orders',(select count(*) from orders where order_status='cancelled'),
    'active_orders',(select count(*) from orders where order_status not in ('completed','delivered','cancelled')),
    'gross_sales',coalesce((select sum(total_amount) from orders where order_status in ('completed','delivered')),0),
    'messages',(select count(*) from order_messages),
    'top_products',coalesce((select jsonb_agg(x) from (
      select p.product_name, sum(oi.quantity)::int quantity, sum(oi.quantity*oi.unit_price) revenue
      from order_items oi join orders o on o.order_id=oi.order_id join products p on p.product_id=oi.product_id
      where o.order_status in ('completed','delivered') group by p.product_id,p.product_name
      order by quantity desc limit 10) x),'[]'::jsonb),
    'no_sales',coalesce((select jsonb_agg(x) from (
      select p.product_name, v.business_name, p.created_at
      from products p join vendors v on v.vendor_id=p.vendor_id
      where not exists (select 1 from order_items oi join orders o on o.order_id=oi.order_id
        where oi.product_id=p.product_id and o.order_status in ('completed','delivered'))
      order by p.created_at desc limit 20) x),'[]'::jsonb),
    'recent_orders',coalesce((select jsonb_agg(x) from (
      select o.order_id,o.total_amount,o.order_status,o.created_at,v.business_name
      from orders o join vendors v on v.vendor_id=o.vendor_id order by o.created_at desc limit 20) x),'[]'::jsonb)
  ) into result;
  return result;
end $$;

grant select,insert on public.order_messages to authenticated;
grant execute on function public.can_access_order_chat(uuid) to authenticated;
grant execute on function public.admin_marketplace_activity() to authenticated;
alter publication supabase_realtime add table public.order_messages;
