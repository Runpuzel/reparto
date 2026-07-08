-- Student Sellers may browse their own listings but cannot purchase them.
create or replace function public.prevent_seller_self_purchase()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_buyer uuid;
  v_seller uuid;
begin
  select c.student_id into v_buyer
  from public.carts c where c.cart_id = new.cart_id;

  select v.user_id into v_seller
  from public.products p
  join public.vendors v on v.vendor_id = p.vendor_id
  where p.product_id = new.product_id;

  if v_buyer is not null and v_buyer = v_seller then
    raise exception 'You cannot buy your own product';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_seller_self_purchase on public.cart_items;
create trigger trg_prevent_seller_self_purchase
before insert or update of product_id, cart_id on public.cart_items
for each row execute function public.prevent_seller_self_purchase();

create or replace function public.prevent_seller_self_order()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from public.vendors v
    where v.vendor_id = new.vendor_id and v.user_id = new.student_id
  ) then
    raise exception 'You cannot place an order with your own shop';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_seller_self_order on public.orders;
create trigger trg_prevent_seller_self_order before insert on public.orders
for each row execute function public.prevent_seller_self_order();
