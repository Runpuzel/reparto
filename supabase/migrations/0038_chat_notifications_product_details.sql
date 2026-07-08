alter table public.products add column if not exists brand text;
alter table public.products add column if not exists item_condition text
  check (item_condition in ('new','used_like_new','used_good','used_fair'));
alter table public.products add column if not exists specifications text;

create or replace function public.notify_order_message()
returns trigger language plpgsql security definer set search_path=public as $$
declare r orders%rowtype; seller_user uuid; recipient uuid;
begin
  select * into r from orders where order_id=new.order_id;
  select user_id into seller_user from vendors where vendor_id=r.vendor_id;
  recipient := case when new.sender_id=r.student_id then seller_user else r.student_id end;
  if recipient is not null and recipient<>new.sender_id then
    insert into notifications(recipient_id,title,body)
    values(recipient,'New order message',left(new.body,120));
  end if;
  return new;
end $$;
drop trigger if exists trg_notify_order_message on public.order_messages;
create trigger trg_notify_order_message after insert on public.order_messages
for each row execute function public.notify_order_message();
