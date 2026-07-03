-- ONE-OFF RECOVERY: run in Supabase SQL Editor only after taking a backup.
-- Prefer Dashboard > Database > Backups when a pre-deletion restore exists.

begin;

-- Recreate the original UUIDs retained in Auth user metadata. Keeping these
-- IDs is important because stale registration metadata may still reference them.
insert into public.campuses (campus_id, campus_name, location, status)
select distinct
  (u.raw_user_meta_data ->> 'campus_id')::uuid,
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'campus_name'), ''),
    'Recovered campus ' || left(u.raw_user_meta_data ->> 'campus_id', 8)
  ),
  'Review and update in Admin',
  'active'::campus_status
from auth.users u
where coalesce(u.raw_user_meta_data ->> 'campus_id', '')
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
on conflict (campus_id) do nothing;

-- Restore the standard choices if they are not represented in Auth metadata.
insert into public.campuses (campus_name, location, status)
select seed.campus_name, seed.location, 'active'::campus_status
from (values
  ('University of Ghana', 'Legon, Accra'),
  ('Kwame Nkrumah Univ. of Sci&Tech', 'Kumasi'),
  ('Ashesi University', 'Berekuso'),
  ('University of Cape Coast', 'Cape Coast')
) as seed(campus_name, location)
where not exists (
  select 1 from public.campuses c where lower(c.campus_name) = lower(seed.campus_name)
);

-- Reconnect student/admin profiles to their original campus where possible.
update public.users profile
set campus_id = (auth_user.raw_user_meta_data ->> 'campus_id')::uuid
from auth.users auth_user
where auth_user.id = profile.user_id
  and profile.campus_id is null
  and coalesce(auth_user.raw_user_meta_data ->> 'campus_id', '')
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.campuses c
    where c.campus_id = (auth_user.raw_user_meta_data ->> 'campus_id')::uuid
  );

commit;

-- Review these results after running the transaction.
select campus_id, campus_name, location, status from public.campuses
order by campus_name;

select
  count(*) filter (where campus_id is null) as users_without_campus,
  count(*) filter (where role = 'vendor') as vendor_user_accounts,
  (select count(*) from public.vendors) as surviving_vendor_records
from public.users;
