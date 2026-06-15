-- ============================================================================
-- Reparto :: Migration 0009 :: Multiple product images
-- ----------------------------------------------------------------------------
-- Adds a product_images table so each product can have several photos.
-- The existing products.image_url is kept as the "cover" (first) image for
-- backwards compatibility and fast list rendering.
--
-- Run AFTER 0001-0008. Safe to run more than once.
-- ============================================================================

create table if not exists public.product_images (
  image_id   uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(product_id) on delete cascade,
  image_url  text not null,
  position   integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_product_images_product
  on public.product_images(product_id);

-- ---------------------------------------------------------------------------
-- RLS: read follows the same rules as products (anyone who can see the product
-- can see its images); write is restricted to the owning vendor / admin.
-- ---------------------------------------------------------------------------
alter table public.product_images enable row level security;

drop policy if exists product_images_read on public.product_images;
create policy product_images_read on public.product_images
  for select using (
    public.is_admin()
    or exists (
      select 1
      from public.products p
      join public.vendors v on v.vendor_id = p.vendor_id
      where p.product_id = product_images.product_id
        and (
          v.user_id = auth.uid()
          or (v.campus_id = public.current_campus()
              and v.approval_status = 'approved')
        )
    )
  );

drop policy if exists product_images_write on public.product_images;
create policy product_images_write on public.product_images
  for all using (
    exists (
      select 1
      from public.products p
      join public.vendors v on v.vendor_id = p.vendor_id
      where p.product_id = product_images.product_id
        and v.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.products p
      join public.vendors v on v.vendor_id = p.vendor_id
      where p.product_id = product_images.product_id
        and v.user_id = auth.uid()
        and v.approval_status = 'approved'
    )
  );

drop policy if exists product_images_admin on public.product_images;
create policy product_images_admin on public.product_images
  for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Backfill: copy any existing single image into the gallery as position 0.
-- ---------------------------------------------------------------------------
insert into public.product_images (product_id, image_url, position)
select product_id, image_url, 0
from public.products
where image_url is not null
  and not exists (
    select 1 from public.product_images pi
    where pi.product_id = products.product_id
  );
