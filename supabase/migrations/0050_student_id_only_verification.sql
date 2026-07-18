-- Student ID is the only supported seller-verification document.
-- Keep previously approved sellers approved while retiring their old type label.
begin;

update public.vendors
set verification_type = null
where verification_type is distinct from 'student_id';

alter table public.vendors
  drop constraint if exists vendors_verification_type_chk;

alter table public.vendors
  add constraint vendors_verification_type_chk check (
    verification_type is null or verification_type = 'student_id'
  );

comment on column public.vendors.verification_type is
  'Student ID verification; student_id for new submissions';

update public.platform_settings
set kyc_allowed_types = array['student_id']::text[]
where kyc_allowed_types is distinct from array['student_id']::text[];

alter table public.platform_settings
  alter column kyc_allowed_types
  set default array['student_id']::text[];

alter table public.platform_settings
  drop constraint if exists platform_settings_student_id_only;

alter table public.platform_settings
  add constraint platform_settings_student_id_only check (
    kyc_allowed_types = array['student_id']::text[]
  );

create or replace function public.vendor_submit_verification(p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vendor_id uuid;
begin
  select vendor_id
  into v_vendor_id
  from vendors
  where user_id = auth.uid();

  if v_vendor_id is null then
    raise exception 'Seller profile not found';
  end if;
  if coalesce(p_payload ->> 'verification_type', 'student_id') <> 'student_id' then
    raise exception 'Only Student ID verification is supported';
  end if;
  if nullif(trim(p_payload ->> 'verification_id_number'), '') is null then
    raise exception 'Student ID number is required';
  end if;
  if nullif(trim(p_payload ->> 'verification_front_url'), '') is null then
    raise exception 'Student ID front image is required';
  end if;

  update vendors
  set verification_type = 'student_id',
      verification_id_number = trim(p_payload ->> 'verification_id_number'),
      verification_front_url = p_payload ->> 'verification_front_url',
      verification_back_url = nullif(p_payload ->> 'verification_back_url', ''),
      verification_selfie_url = null,
      verification_status = 'pending',
      is_verified = false,
      verification_submitted_at = now(),
      verification_approved_at = null,
      verification_rejected_reason = null,
      updated_at = now()
  where vendor_id = v_vendor_id;
end;
$$;

create or replace function public.set_platform_settings(p_settings jsonb)
returns public.platform_settings
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.platform_settings%rowtype;
  v_id uuid;
  v_auth_fee numeric;
  v_auth_days integer;
  v_free_days integer;
  v_seller_fee numeric;
  v_verification_required boolean;
  v_kyc text[] := array['student_id']::text[];
  v_policy_version text;
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;

  select *
  into r
  from public.platform_settings
  order by updated_at desc, created_at desc
  limit 1
  for update;

  v_id := r.id;
  v_auth_fee := coalesce(
    (p_settings ->> 'service_auth_fee')::numeric,
    r.service_auth_fee,
    0
  );
  v_auth_days := coalesce(
    (p_settings ->> 'service_auth_duration_days')::integer,
    r.service_auth_duration_days,
    30
  );
  v_free_days := coalesce(
    (p_settings ->> 'service_free_listing_days')::integer,
    r.service_free_listing_days,
    14
  );
  v_seller_fee := coalesce(
    (p_settings ->> 'platform_fee_seller_percent')::numeric,
    r.platform_fee_seller_percent,
    5
  );
  v_verification_required := coalesce(
    (p_settings ->> 'verification_required_for_prepayment')::boolean,
    r.verification_required_for_prepayment,
    true
  );
  v_policy_version := coalesce(
    nullif(trim(p_settings ->> 'current_policy_version'), ''),
    r.current_policy_version,
    'v1.0-2025-07'
  );

  if v_auth_fee < 0
     or v_auth_days not between 1 and 365
     or v_free_days not between 0 and 365
     or v_seller_fee not between 0 and 100 then
    raise exception 'One or more platform settings are outside the allowed range';
  end if;

  if v_id is null then
    insert into public.platform_settings (
      service_auth_fee,
      service_auth_duration_days,
      service_free_listing_days,
      platform_fee_seller_percent,
      verification_required_for_prepayment,
      kyc_allowed_types,
      current_policy_version
    ) values (
      v_auth_fee,
      v_auth_days,
      v_free_days,
      v_seller_fee,
      v_verification_required,
      v_kyc,
      v_policy_version
    )
    returning * into r;
  else
    update public.platform_settings
    set service_auth_fee = v_auth_fee,
        service_auth_duration_days = v_auth_days,
        service_free_listing_days = v_free_days,
        platform_fee_seller_percent = v_seller_fee,
        verification_required_for_prepayment = v_verification_required,
        kyc_allowed_types = v_kyc,
        current_policy_version = v_policy_version,
        updated_at = now()
    where id = v_id
    returning * into r;
  end if;

  return r;
end;
$$;

grant execute on function public.vendor_submit_verification(jsonb)
to authenticated;
grant execute on function public.set_platform_settings(jsonb)
to authenticated;

commit;
