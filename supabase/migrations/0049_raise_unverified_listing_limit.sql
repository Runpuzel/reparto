-- Allow unverified sellers to publish up to 15 combined product and service
-- listings. Identity verification is required starting with listing 16.
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
  if v_count >= 15 then
    raise exception 'Identity verification is required to publish more than 15 listings';
  end if;
  return new;
end; $$;
