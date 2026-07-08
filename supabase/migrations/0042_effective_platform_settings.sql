-- Atomic singleton administration for every platform setting.

delete from public.platform_settings
where id not in (
  select id from public.platform_settings order by updated_at desc,created_at desc limit 1
);

create unique index if not exists platform_settings_singleton
on public.platform_settings ((true));

create or replace function public.set_platform_settings(p_settings jsonb)
returns public.platform_settings
language plpgsql security definer set search_path=public as $$
declare r platform_settings%rowtype;
  v_auth_fee numeric; v_auth_days int; v_free_days int;
  v_seller_fee numeric; v_service_fee numeric; v_kyc text[];
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;
  v_auth_fee:=(p_settings->>'service_auth_fee')::numeric;
  v_auth_days:=(p_settings->>'service_auth_duration_days')::int;
  v_free_days:=(p_settings->>'service_free_listing_days')::int;
  v_seller_fee:=(p_settings->>'platform_fee_seller_percent')::numeric;
  v_service_fee:=(p_settings->>'platform_fee_service_percent')::numeric;
  select coalesce(array_agg(x),array[]::text[]) into v_kyc
  from jsonb_array_elements_text(coalesce(p_settings->'kyc_allowed_types','[]')) x;
  if v_auth_fee<0 or v_auth_days not between 1 and 365 or
     v_free_days not between 0 and 365 or
     v_seller_fee not between 0 and 100 or
     v_service_fee not between 0 and 100 then
    raise exception 'One or more platform settings are outside the allowed range';
  end if;
  if coalesce((p_settings->>'verification_required_for_prepayment')::boolean,true)
     and cardinality(v_kyc)=0 then
    raise exception 'At least one KYC document type is required';
  end if;
  if exists(select 1 from unnest(v_kyc) x where x not in ('ghana_card','student_id')) then
    raise exception 'Unsupported KYC document type';
  end if;
  update platform_settings set
    service_auth_fee=v_auth_fee,
    service_auth_duration_days=v_auth_days,
    service_free_listing_days=v_free_days,
    platform_fee_seller_percent=v_seller_fee,
    platform_fee_service_percent=v_service_fee,
    verification_required_for_prepayment=coalesce((p_settings->>'verification_required_for_prepayment')::boolean,true),
    kyc_allowed_types=v_kyc,
    current_policy_version=trim(p_settings->>'current_policy_version'),
    updated_at=now()
  returning * into r;
  if not found then
    insert into platform_settings(service_auth_fee,service_auth_duration_days,
      service_free_listing_days,platform_fee_seller_percent,platform_fee_service_percent,
      verification_required_for_prepayment,kyc_allowed_types,current_policy_version)
    values(v_auth_fee,v_auth_days,v_free_days,v_seller_fee,v_service_fee,
      coalesce((p_settings->>'verification_required_for_prepayment')::boolean,true),
      v_kyc,trim(p_settings->>'current_policy_version')) returning * into r;
  end if;
  return r;
end $$;

grant execute on function public.set_platform_settings(jsonb) to authenticated;
