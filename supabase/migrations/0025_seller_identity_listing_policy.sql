create or replace function public.enforce_unverified_listing_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_verified boolean; v_status approval_status; v_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.vendor_id::text, 0));
  select is_verified, approval_status into v_verified, v_status
  from public.vendors where vendor_id = new.vendor_id;
  if v_status in ('suspended', 'rejected') then
    raise exception 'This seller account cannot publish listings';
  end if;
  if coalesce(v_verified, false) then return new; end if;
  select (select count(*) from public.products where vendor_id = new.vendor_id) +
         (select count(*) from public.services where vendor_id = new.vendor_id)
    into v_count;
  if v_count >= 5 then
    raise exception 'Identity verification is required to publish more than 5 listings';
  end if;
  return new;
end; $$;

drop trigger if exists trg_unverified_product_limit on public.products;
create trigger trg_unverified_product_limit before insert on public.products
for each row execute function public.enforce_unverified_listing_limit();
drop trigger if exists trg_unverified_service_limit on public.services;
create trigger trg_unverified_service_limit before insert on public.services
for each row execute function public.enforce_unverified_listing_limit();

drop policy if exists products_campus_read on public.products;
create policy products_campus_read on public.products for select using (
  public.is_admin() or exists (select 1 from public.vendors v
  where v.vendor_id = products.vendor_id and (v.user_id = auth.uid() or
    (v.campus_id = public.current_campus() and v.approval_status not in ('suspended','rejected')))));
drop policy if exists products_vendor_write on public.products;
create policy products_vendor_write on public.products for all using (
  exists (select 1 from public.vendors v where v.vendor_id = products.vendor_id and v.user_id = auth.uid()))
with check (exists (select 1 from public.vendors v where v.vendor_id = products.vendor_id
  and v.user_id = auth.uid() and v.approval_status not in ('suspended','rejected')));

drop policy if exists services_read on public.services;
create policy services_read on public.services for select using (
  public.is_admin() or exists (select 1 from public.vendors v
  where v.vendor_id = services.vendor_id and (v.user_id = auth.uid() or
    ((auth.uid() is null or v.campus_id = public.current_campus()) and
     v.approval_status not in ('suspended','rejected')))));
drop policy if exists services_owner_write on public.services;
create policy services_owner_write on public.services for all using (
  exists (select 1 from public.vendors v where v.vendor_id = services.vendor_id and v.user_id = auth.uid()))
with check (exists (select 1 from public.vendors v where v.vendor_id = services.vendor_id
  and v.user_id = auth.uid() and v.approval_status not in ('suspended','rejected')));
