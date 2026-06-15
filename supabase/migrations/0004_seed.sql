-- ============================================================================
-- Reparto :: Migration 0004 :: Seed Data (development only)
-- ----------------------------------------------------------------------------
-- Safe to run multiple times. Seeds campuses & categories.
-- NOTE: real users are created through Supabase Auth; create an admin by
--       signing up, then promoting the row:
--         update public.users set role = 'admin' where email = 'you@uni.edu';
-- ============================================================================

insert into public.campuses (campus_name, location, status) values
  ('University of Ghana',            'Legon, Accra',     'active'),
  ('Kwame Nkrumah Univ. of Sci&Tech','Kumasi',           'active'),
  ('Ashesi University',              'Berekuso',         'active'),
  ('University of Cape Coast',       'Cape Coast',       'active')
on conflict do nothing;

insert into public.categories (category_name, description) values
  ('Food & Drinks',  'Meals, snacks and beverages'),
  ('Stationery',     'Books, pens and study supplies'),
  ('Electronics',    'Gadgets and accessories'),
  ('Fashion',        'Clothing and accessories'),
  ('Services',       'Printing, laundry and other services'),
  ('Groceries',      'Everyday essentials')
on conflict (category_name) do nothing;
