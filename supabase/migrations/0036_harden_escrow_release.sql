-- Receipt confirmation is the escrow release boundary for prepaid orders.
create or replace function public.confirm_receipt(p_order uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid(); r_order public.orders%rowtype;
begin
  select * into r_order from public.orders
  where order_id = p_order and student_id = v_me for update;
  if r_order.order_id is null then raise exception 'Order not found'; end if;
  if r_order.order_status <> 'delivered' then
    raise exception 'You can only confirm receipt once the order is delivered';
  end if;
  if r_order.payment_method <> 'cash_on_delivery' and r_order.payment_status <> 'paid' then
    raise exception 'Payment has not been verified';
  end if;
  update public.orders set order_status='completed', completed_at=now()
  where order_id=p_order;
  perform public.reward_first_transaction(v_me);
  insert into public.notifications(recipient_id,title,body)
  select v.user_id,
    case when r_order.payment_method='cash_on_delivery' then 'Order completed' else 'Payment released' end,
    case when r_order.payment_method='cash_on_delivery'
      then 'A buyer confirmed receipt of their order.'
      else 'A buyer confirmed receipt — your payment has been released.' end
  from public.vendors v where v.vendor_id=r_order.vendor_id;
end;
$$;

revoke all on function public.auto_release_due_orders() from public, anon, authenticated;
grant execute on function public.auto_release_due_orders() to service_role;

-- Run the overdue escrow sweep every 15 minutes. Safe to reapply.
create extension if not exists pg_cron;
do $$
begin
  if not exists (select 1 from cron.job where jobname = 'ujustbuy-auto-release') then
    perform cron.schedule(
      'ujustbuy-auto-release',
      '*/15 * * * *',
      'select public.auto_release_due_orders()'
    );
  end if;
end;
$$;
