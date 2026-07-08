-- Limit the student-facing campus catalog to the supported USTED campuses.
-- Stable IDs are retained so existing user and listing references remain valid.

update public.campuses
set campus_name = 'USTED-K',
    location = 'Kumasi',
    status = 'active'
where campus_id = '10000000-0000-4000-8000-000000000001';

update public.campuses
set campus_name = 'USTED-MAMPONG',
    location = 'Mampong',
    status = 'active'
where campus_id = '10000000-0000-4000-8000-000000000002';

update public.campuses
set status = 'inactive'
where campus_id not in (
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002'
);
