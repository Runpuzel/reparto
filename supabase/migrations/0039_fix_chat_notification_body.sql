-- Correct installations where migration 0038 created the trigger with the
-- obsolete `message` notification column.
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
