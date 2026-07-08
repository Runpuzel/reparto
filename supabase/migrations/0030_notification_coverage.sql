-- Ensure every in-app notification is dispatched to registered devices.
drop trigger if exists trg_dispatch_push on public.notifications;
create trigger trg_dispatch_push
after insert on public.notifications
for each row execute function public.dispatch_push();

-- Notify users when tokens are earned or redeemed.
create or replace function public.notify_token_activity()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications(recipient_id, title, body)
  values (
    new.user_id,
    case when new.delta > 0 then 'Tokens earned' else 'Tokens redeemed' end,
    case when new.delta > 0
      then '+' || new.delta || ' tokens · ' || new.reason
      else abs(new.delta) || ' tokens used · ' || new.reason end
  );
  return new;
end $$;
drop trigger if exists trg_notify_token_activity on public.token_transactions;
create trigger trg_notify_token_activity after insert on public.token_transactions
for each row execute function public.notify_token_activity();

-- Notify a seller whenever a buyer leaves a review.
create or replace function public.notify_new_review()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_seller uuid;
begin
  select user_id into v_seller from public.vendors where vendor_id = new.vendor_id;
  insert into public.notifications(recipient_id, title, body)
  values (v_seller, 'New customer review',
          'You received a ' || new.rating || '-star review.');
  return new;
end $$;
drop trigger if exists trg_notify_new_review on public.reviews;
create trigger trg_notify_new_review after insert on public.reviews
for each row execute function public.notify_new_review();

-- Notify sellers when an item reaches low or zero stock after a purchase.
create or replace function public.notify_low_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_seller uuid;
begin
  if new.quantity_available <= 3
     and old.quantity_available > new.quantity_available then
    select v.user_id into v_seller from public.vendors v
      where v.vendor_id = new.vendor_id;
    insert into public.notifications(recipient_id, title, body)
    values (v_seller,
      case when new.quantity_available = 0 then 'Product sold out' else 'Low stock' end,
      new.product_name || ' has ' || new.quantity_available || ' left.');
  end if;
  return new;
end $$;
drop trigger if exists trg_notify_low_stock on public.products;
create trigger trg_notify_low_stock after update of quantity_available on public.products
for each row execute function public.notify_low_stock();
