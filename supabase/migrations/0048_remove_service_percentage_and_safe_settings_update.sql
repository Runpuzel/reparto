-- Remove the unused service transaction percentage and make platform setting
-- updates compatible with databases that reject UPDATE statements without a
-- WHERE clause. The fixed service-listing authorization fee remains intact.

begin;

-- Keep the existing two-argument signature for database-function compatibility,
-- but fail explicitly if an obsolete service-transaction calculation is used.
create or replace function public.marketplace_fee_for_amount(
  p_amount_pesewas integer,
  p_is_service boolean default false
) returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rate numeric;
begin
  if p_amount_pesewas < 0 then
    raise exception 'Marketplace fee amount cannot be negative';
  end if;
  if p_is_service then
    raise exception 'Service transaction percentage fees are not supported';
  end if;

  select platform_fee_seller_percent
  into v_rate
  from public.platform_settings
  order by updated_at desc
  limit 1;

  if v_rate is null then
    raise exception 'Marketplace fee settings are unavailable. Contact support before confirming this order.';
  end if;
  if v_rate < 0 or v_rate > 100 then
    raise exception 'Marketplace fee settings are invalid. Contact support before confirming this order.';
  end if;

  return greatest(
    0,
    least(p_amount_pesewas, round(p_amount_pesewas * v_rate / 100.0)::integer)
  );
end;
$$;

-- Accept both the complete Platform Settings form and the smaller service
-- listing form. Missing values retain their current settings.
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
  v_kyc text[];
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

  if p_settings ? 'kyc_allowed_types' then
    select coalesce(array_agg(value), array[]::text[])
    into v_kyc
    from jsonb_array_elements_text(
      coalesce(p_settings -> 'kyc_allowed_types', '[]'::jsonb)
    );
  else
    v_kyc := coalesce(
      r.kyc_allowed_types,
      array['ghana_card', 'student_id']::text[]
    );
  end if;

  if v_auth_fee < 0
     or v_auth_days not between 1 and 365
     or v_free_days not between 0 and 365
     or v_seller_fee not between 0 and 100 then
    raise exception 'One or more platform settings are outside the allowed range';
  end if;
  if v_verification_required and cardinality(v_kyc) = 0 then
    raise exception 'At least one KYC document type is required';
  end if;
  if exists (
    select 1 from unnest(v_kyc) value
    where value not in ('ghana_card', 'student_id')
  ) then
    raise exception 'Unsupported KYC document type';
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

alter table public.platform_settings
  drop constraint if exists platform_settings_fee_ranges;

alter table public.platform_settings
  drop column if exists platform_fee_service_percent;

alter table public.platform_settings
  add constraint platform_settings_fee_ranges check (
    service_auth_fee >= 0
    and service_auth_duration_days between 1 and 365
    and service_free_listing_days between 0 and 365
    and platform_fee_seller_percent between 0 and 100
  );

revoke all on function public.marketplace_fee_for_amount(integer, boolean)
from public;
grant execute on function public.marketplace_fee_for_amount(integer, boolean)
to anon, authenticated;
grant execute on function public.set_platform_settings(jsonb)
to authenticated;

commit;
