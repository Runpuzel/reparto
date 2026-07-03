-- Restore the supported campus catalog after a data reset.
-- Stable UUIDs keep development, staging, and production references aligned.

insert into public.campuses (campus_id, campus_name, location, status)
values
  ('10000000-0000-4000-8000-000000000001',
   'University of Ghana', 'Legon, Accra', 'active'),
  ('10000000-0000-4000-8000-000000000002',
   'Kwame Nkrumah University of Science and Technology', 'Kumasi', 'active'),
  ('10000000-0000-4000-8000-000000000003',
   'Ashesi University', 'Berekuso', 'active'),
  ('10000000-0000-4000-8000-000000000004',
   'University of Cape Coast', 'Cape Coast', 'active')
on conflict (campus_id) do update
set campus_name = excluded.campus_name,
    location = excluded.location,
    status = excluded.status;
