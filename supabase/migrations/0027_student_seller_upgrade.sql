-- Allow a student to enable seller tools without losing buyer capabilities.
-- The operation is atomic and can only affect the authenticated account.

create or replace function public.become_student_seller()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.users%rowtype;
  v_vendor_id uuid;
begin
  select * into v_user
  from public.users
  where user_id = auth.uid()
  for update;

  if v_user.user_id is null then
    raise exception 'User profile not found';
  end if;
  if v_user.role = 'admin' then
    raise exception 'Administrator accounts cannot become sellers';
  end if;
  if v_user.campus_id is null then
    raise exception 'Select a campus before becoming a seller';
  end if;

  insert into public.vendors (
    user_id, business_name, owner_name, campus_id, approval_status
  ) values (
    v_user.user_id,
    coalesce(nullif(trim(v_user.full_name), ''), 'Student Seller'),
    v_user.full_name,
    v_user.campus_id,
    'pending'
  )
  on conflict (user_id) do update
    set campus_id = excluded.campus_id
  returning vendor_id into v_vendor_id;

  update public.users
  set role = 'vendor'
  where user_id = v_user.user_id;

  return v_vendor_id;
end;
$$;

revoke all on function public.become_student_seller() from public;
grant execute on function public.become_student_seller() to authenticated;
