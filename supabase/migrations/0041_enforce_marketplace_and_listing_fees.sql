-- Enforce admin marketplace fees and paid/free service listing policy.

alter table public.platform_settings
  drop constraint if exists platform_settings_fee_ranges;
alter table public.platform_settings
  add constraint platform_settings_fee_ranges check (
    service_auth_fee >= 0 and
    service_auth_duration_days between 1 and 365 and
    service_free_listing_days between 0 and 365 and
    platform_fee_seller_percent between 0 and 100 and
    platform_fee_service_percent between 0 and 100
  );

create or replace function public.apply_service_listing_policy()
returns trigger language plpgsql security definer set search_path=public as $$
declare s platform_settings%rowtype;
begin
  select * into s from platform_settings order by updated_at desc limit 1;
  if coalesce(s.service_auth_fee,0)=0 then
    new.expires_at:=null;
  elsif coalesce(new.is_authorized,false)=false then
    new.expires_at:=coalesce(new.expires_at,
      now()+make_interval(days=>s.service_free_listing_days));
  end if;
  return new;
end $$;
drop trigger if exists trg_apply_service_listing_policy on public.services;
create trigger trg_apply_service_listing_policy before insert on public.services
for each row execute function public.apply_service_listing_policy();

create or replace function public.sync_service_free_mode()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if old.service_auth_fee=0 and new.service_auth_fee>0 then
    update services set
      expires_at=now()+make_interval(days=>new.service_free_listing_days),
      status='available'
    where coalesce(is_authorized,false)=false;
  elsif old.service_auth_fee>0 and new.service_auth_fee=0 then
    update services set expires_at=null,status='available'
    where coalesce(is_authorized,false)=false;
  end if;
  return new;
end $$;
drop trigger if exists trg_sync_service_free_mode on public.platform_settings;
create trigger trg_sync_service_free_mode after update of service_auth_fee
on public.platform_settings for each row execute function public.sync_service_free_mode();

create or replace function public.authorize_service_from_wallet(p_service uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_service services%rowtype; v_vendor vendors%rowtype;
  v_settings platform_settings%rowtype; v_fee integer; v_balance integer;
begin
  select * into v_service from services where service_id=p_service for update;
  select * into v_vendor from vendors where vendor_id=v_service.vendor_id;
  if v_service.service_id is null or v_vendor.user_id<>auth.uid() then
    raise exception 'Service not found or access denied';
  end if;
  select * into v_settings from platform_settings order by updated_at desc limit 1;
  v_fee:=round(coalesce(v_settings.service_auth_fee,0)*100)::integer;
  if v_fee<=0 then raise exception 'Free listing mode is active; no payment is required'; end if;
  if coalesce(v_service.is_authorized,false) and
     v_service.authorization_expires_at>now() then
    raise exception 'This service is already authorized';
  end if;
  insert into vendor_wallets(vendor_id) values(v_vendor.vendor_id)
  on conflict(vendor_id) do nothing;
  select available_pesewas into v_balance from vendor_wallets
  where vendor_id=v_vendor.vendor_id for update;
  if v_balance<v_fee then
    raise exception 'Insufficient wallet balance. Add at least GH% to authorize this service.',
      to_char((v_fee-v_balance)/100.0,'FM999999990.00');
  end if;
  update vendor_wallets set available_pesewas=available_pesewas-v_fee,
    updated_at=now() where vendor_id=v_vendor.vendor_id;
  update services set is_authorized=true,status='available',
    authorization_fee_paid=v_fee/100.0,authorization_paid_at=now(),
    authorization_expires_at=now()+make_interval(days=>v_settings.service_auth_duration_days),
    expires_at=now()+make_interval(days=>v_settings.service_auth_duration_days),
    updated_at=now() where service_id=p_service;
  insert into wallet_transactions(vendor_id,kind,amount_pesewas,reference,description)
  values(v_vendor.vendor_id,'capture',v_fee,'service-auth-'||p_service||'-'||extract(epoch from now())::bigint,
    'Service listing authorization fee');
end $$;

grant execute on function public.authorize_service_from_wallet(uuid) to authenticated;
