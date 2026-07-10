-- UjustBUY :: Migration 0043 :: Campus marketplace categories
-- Adds practical product and service categories for student sellers.

insert into public.categories (category_name, description) values
  ('Food & Snacks', 'Cooked meals, pastries, snacks, drinks and campus food packs'),
  ('Groceries & Provisions', 'Toiletries, water, beverages, breakfast items and daily essentials'),
  ('Fashion & Clothing', 'Shirts, dresses, shoes, bags, jewelry and thrift clothing'),
  ('Beauty & Personal Care', 'Hair products, skincare, perfumes, cosmetics and grooming items'),
  ('Electronics & Accessories', 'Phones, chargers, earphones, power banks and tech accessories'),
  ('Books & Stationery', 'Textbooks, notebooks, pens, calculators and study supplies'),
  ('Room & Hostel Essentials', 'Buckets, bedsheets, hangers, lamps, extension boards and room items'),
  ('Kitchen & Cooking Items', 'Rice cookers, flasks, utensils, food containers and small appliances'),
  ('Health & Wellness', 'Basic wellness items, sanitary products and fitness accessories'),
  ('Sports & Fitness', 'Jerseys, boots, gym items, balls and sportswear'),
  ('Art, Prints & Gifts', 'Frames, drawings, handmade gifts, stickers and custom prints'),
  ('Tickets & Events', 'Campus event tickets, flyers, wristbands and approved event items'),
  ('Pre-owned Items', 'Second-hand items, used electronics, books, furniture and clothing'),
  ('Other', 'Items that do not fit the main campus marketplace categories')
on conflict (category_name) do update
set description = excluded.description;

alter type public.service_category add value if not exists 'beauty_makeup';
alter type public.service_category add value if not exists 'printing_typing';
alter type public.service_category add value if not exists 'delivery_errands';
alter type public.service_category add value if not exists 'room_cleaning';
alter type public.service_category add value if not exists 'event_support';
alter type public.service_category add value if not exists 'food_catering';
alter type public.service_category add value if not exists 'fitness_sports';
