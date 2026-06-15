-- ============================================================================
-- Reparto :: Migration 0007 :: Storage Buckets & Policies
-- ----------------------------------------------------------------------------
-- Buckets:
--   product-images  (PUBLIC)  – product photos, readable by anyone, written by
--                               the owning vendor.
--   business-logos  (PUBLIC)  – vendor logos, readable by anyone, written by
--                               the owning vendor.
--   kyc-documents   (PRIVATE) – Ghana Card images. Readable only by the
--                               uploading vendor and admins.
--
-- Folder convention: files are stored under  <auth.uid()>/<filename>
-- so the first path segment identifies the owner.
--
-- Run AFTER 0006. Safe to run more than once.
-- ============================================================================

insert into storage.buckets (id, name, public)
values
  ('product-images', 'product-images', true),
  ('business-logos', 'business-logos', true),
  ('kyc-documents',  'kyc-documents',  false)
on conflict (id) do nothing;

-- Helper: first folder of an object name == the owner's uid.
-- storage.foldername(name) returns text[]; element 1 is the top folder.

-- ---------------------------------------------------------------------------
-- PRODUCT IMAGES (public read, owner write)
-- ---------------------------------------------------------------------------
drop policy if exists "product_images_read" on storage.objects;
create policy "product_images_read" on storage.objects
  for select using (bucket_id = 'product-images');

drop policy if exists "product_images_write" on storage.objects;
create policy "product_images_write" on storage.objects
  for insert with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "product_images_update" on storage.objects;
create policy "product_images_update" on storage.objects
  for update using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "product_images_delete" on storage.objects;
create policy "product_images_delete" on storage.objects
  for delete using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- BUSINESS LOGOS (public read, owner write)
-- ---------------------------------------------------------------------------
drop policy if exists "business_logos_read" on storage.objects;
create policy "business_logos_read" on storage.objects
  for select using (bucket_id = 'business-logos');

drop policy if exists "business_logos_write" on storage.objects;
create policy "business_logos_write" on storage.objects
  for insert with check (
    bucket_id = 'business-logos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "business_logos_update" on storage.objects;
create policy "business_logos_update" on storage.objects
  for update using (
    bucket_id = 'business-logos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "business_logos_delete" on storage.objects;
create policy "business_logos_delete" on storage.objects
  for delete using (
    bucket_id = 'business-logos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- KYC DOCUMENTS (private: owner + admin read; owner write)
-- ---------------------------------------------------------------------------
drop policy if exists "kyc_read" on storage.objects;
create policy "kyc_read" on storage.objects
  for select using (
    bucket_id = 'kyc-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  );

drop policy if exists "kyc_write" on storage.objects;
create policy "kyc_write" on storage.objects
  for insert with check (
    bucket_id = 'kyc-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "kyc_update" on storage.objects;
create policy "kyc_update" on storage.objects
  for update using (
    bucket_id = 'kyc-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
