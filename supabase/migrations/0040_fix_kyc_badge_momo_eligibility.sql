-- Make KYC approval, verified badge, and prepayment eligibility one state.

update public.vendors
set is_verified = true,
    verification_approved_at = coalesce(verification_approved_at, now())
where verification_status = 'approved' and is_verified is distinct from true;

update public.vendors
set is_verified = false
where verification_status <> 'approved' and is_verified is distinct from false;

create or replace function public.vendor_submit_verification(p_payload jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare v_vendor_id uuid;
begin
  select vendor_id into v_vendor_id from vendors where user_id=auth.uid();
  if v_vendor_id is null then raise exception 'Seller profile not found'; end if;
  if nullif(trim(p_payload->>'verification_id_number'),'') is null then
    raise exception 'ID number is required';
  end if;
  if nullif(trim(p_payload->>'verification_front_url'),'') is null then
    raise exception 'Front ID image is required';
  end if;
  update vendors set
    verification_type=p_payload->>'verification_type',
    verification_id_number=trim(p_payload->>'verification_id_number'),
    verification_front_url=p_payload->>'verification_front_url',
    verification_back_url=nullif(p_payload->>'verification_back_url',''),
    verification_selfie_url=null,
    verification_status='pending', is_verified=false,
    verification_submitted_at=now(), verification_approved_at=null,
    verification_rejected_reason=null, updated_at=now()
  where vendor_id=v_vendor_id;
end $$;

create or replace function public.admin_review_verification(
  p_vendor_id uuid, p_approve boolean, p_reason text default null
) returns void language plpgsql security definer set search_path=public as $$
declare v_old text; v_seller uuid;
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;
  select verification_status,user_id into v_old,v_seller
  from vendors where vendor_id=p_vendor_id for update;
  if v_seller is null then raise exception 'Seller not found'; end if;
  if v_old <> 'pending' then raise exception 'Only pending verification can be reviewed'; end if;
  insert into verification_audit_log(vendor_id,admin_id,old_status,new_status,reason)
  values(p_vendor_id,auth.uid(),v_old,case when p_approve then 'approved' else 'rejected' end,p_reason);
  update vendors set
    verification_status=case when p_approve then 'approved' else 'rejected' end,
    is_verified=p_approve,
    verification_approved_at=case when p_approve then now() else null end,
    verification_rejected_reason=case when p_approve then null else p_reason end,
    updated_at=now()
  where vendor_id=p_vendor_id;
  insert into notifications(recipient_id,title,body)
  values(v_seller,
    case when p_approve then 'Identity verified' else 'Verification needs attention' end,
    case when p_approve then 'Your Verified Student Seller badge is active. Mobile Money payments are now enabled.'
         else 'Your identity verification was not approved. '||coalesce(p_reason,'Please review and resubmit your documents.') end);
end $$;

grant execute on function public.vendor_submit_verification(jsonb) to authenticated;
grant execute on function public.admin_review_verification(uuid,boolean,text) to authenticated;
