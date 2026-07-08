-- Protect paid orders from cancellation, payment reversal, and identity edits.
create or replace function public.enforce_order_payment_integrity()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() = old.student_id
     and new.order_status is distinct from old.order_status
     and not (
       (old.order_status = 'pending' and new.order_status = 'cancelled'
        and old.payment_status <> 'paid')
       or (old.order_status = 'delivered' and new.order_status = 'completed')
       or new.order_status = 'disputed'
     ) then
    raise exception 'This order status change is not available to the buyer';
  end if;
  if old.payment_status = 'paid'
     and new.payment_status is distinct from old.payment_status then
    raise exception 'A verified payment cannot be changed or reversed directly';
  end if;
  if old.payment_status = 'paid'
     and old.payment_method <> 'cash_on_delivery'
     and new.order_status = 'cancelled'
     and old.order_status is distinct from 'cancelled' then
    raise exception 'Paid Mobile Money orders cannot be cancelled; open a dispute instead';
  end if;
  if new.student_id is distinct from old.student_id
     or new.vendor_id is distinct from old.vendor_id then
    raise exception 'Order buyer and seller cannot be changed';
  end if;
  if old.payment_reference is not null
     and new.payment_reference is distinct from old.payment_reference then
    raise exception 'Payment reference cannot be changed';
  end if;
  if old.total_amount > 0 and new.total_amount is distinct from old.total_amount then
    raise exception 'Order total cannot be changed after creation';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_order_payment_integrity on public.orders;
create trigger trg_enforce_order_payment_integrity before update on public.orders
for each row execute function public.enforce_order_payment_integrity();

create unique index if not exists orders_payment_reference_unique
on public.orders(payment_reference, vendor_id)
where payment_reference is not null;
