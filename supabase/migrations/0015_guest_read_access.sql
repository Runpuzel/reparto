-- ============================================================================
-- UjustBUY :: Migration 0015 :: Guest (anonymous) read access
-- ----------------------------------------------------------------------------
-- Spec PART ONE: "Guests can browse freely." Guests are the Supabase `anon`
-- role and have no campus binding, so `current_campus()` is null for them.
-- These policies let anon READ the public catalogue (active campuses, approved
-- sellers, their available products + images, and categories). All write paths
-- remain authenticated/owner/admin only (unchanged).
--
-- Run AFTER 0014. Idempotent — safe to re-run.
-- ============================================================================

-- ---- CATEGORIES : allow everyone (incl. guests) to read --------------------
drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories
  for select using (true);

-- ---- VENDORS : guests may read APPROVED sellers (any campus) ---------------
-- Signed-in users keep campus-scoped visibility; owners/admins unchanged.
drop policy if exists vendors_read on public.vendors;
create policy vendors_read on public.vendors
  for select using (
    public.is_admin()
    or user_id = auth.uid()
    or (auth.uid() is not null and campus_id = public.current_campus())
    or (auth.uid() is null and approval_status = 'approved')
  );

-- ---- PRODUCTS : guests may read available products of approved sellers -----
drop policy if exists products_campus_read on public.products;
create policy products_campus_read on public.products
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.vendors v
      where v.vendor_id = products.vendor_id
        and (
          v.user_id = auth.uid()  -- owner sees all their own
          or (auth.uid() is not null
              and v.campus_id = public.current_campus()
              and v.approval_status = 'approved')
          or (auth.uid() is null and v.approval_status = 'approved')
        )
    )
  );

-- ---- PRODUCT IMAGES : readable whenever the parent product is readable -----
-- (RLS on product_images defers to product visibility; make anon explicit.)
do $$
begin
  if exists (
    select 1 from pg_tables
    where schemaname = 'public' and tablename = 'product_images'
  ) then
    execute 'alter table public.product_images enable row level security';
    execute 'drop policy if exists product_images_read on public.product_images';
    execute $p$
      create policy product_images_read on public.product_images
        for select using (
          exists (
            select 1 from public.products p
            where p.product_id = product_images.product_id
          )
        )
    $p$;
  end if;
end $$;

-- Reviews are public social proof on listings → allow guest read.
do $$
begin
  if exists (
    select 1 from pg_tables
    where schemaname = 'public' and tablename = 'reviews'
  ) then
    execute 'drop policy if exists reviews_public_read on public.reviews';
    execute 'create policy reviews_public_read on public.reviews for select using (true)';
  end if;
end $$;
