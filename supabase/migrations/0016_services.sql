-- ============================================================================
-- UjustBUY :: Migration 0016 :: Student Services marketplace
-- ----------------------------------------------------------------------------
-- A second listing type: services offered by sellers (spec Section D).
-- Mirrors the products model: a service belongs to a vendor (= Student Seller),
-- is campus-scoped via the owning vendor, price in numeric cedis (the pesewa
-- calc layer handles exact math client-side, consistent with products).
--
-- Service categories are a fixed enum per spec D2. Photos are optional and live
-- in a `service_images` child table (same shape as product_images).
--
-- Run AFTER 0015. Idempotent.
-- ============================================================================

-- ---- 1. Service category enum ---------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'service_category') then
    create type service_category as enum (
      'hair_grooming',
      'technical_repairs',
      'home_room_services',
      'academic_support',
      'creative_services',
      'laundry_cleaning',
      'transport_errands',
      'other'
    );
  end if;
end $$;

-- ---- 2. services table -----------------------------------------------------
create table if not exists public.services (
  service_id     uuid primary key default gen_random_uuid(),
  vendor_id      uuid not null references public.vendors(vendor_id) on delete cascade,
  title          text not null,
  description    text,
  category       service_category not null default 'other',
  price          numeric(12,2) not null default 0 check (price >= 0),
  price_from     boolean not null default false,   -- "Starting from" pricing
  availability   text,                              -- free-text availability
  location       text,                              -- where the service happens
  image_url      text,                              -- cover (optional)
  status         availability_status not null default 'available',
  created_at     timestamptz not null default now()
);

create index if not exists idx_services_vendor   on public.services(vendor_id);
create index if not exists idx_services_category  on public.services(category);

-- ---- 3. service_images (optional portfolio) --------------------------------
create table if not exists public.service_images (
  image_id   uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services(service_id) on delete cascade,
  image_url  text not null,
  position   integer not null default 0
);
create index if not exists idx_service_images_service
  on public.service_images(service_id);

-- ---- 4. RLS ----------------------------------------------------------------
alter table public.services       enable row level security;
alter table public.service_images enable row level security;

-- READ: same visibility rules as products — guests & campus users see services
-- of APPROVED sellers; owners see their own; admins all.
drop policy if exists services_read on public.services;
create policy services_read on public.services
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.vendors v
      where v.vendor_id = services.vendor_id
        and (
          v.user_id = auth.uid()
          or (auth.uid() is not null
              and v.campus_id = public.current_campus()
              and v.approval_status = 'approved')
          or (auth.uid() is null and v.approval_status = 'approved')
        )
    )
  );

-- WRITE: a seller manages their own services; admins manage all.
drop policy if exists services_owner_write on public.services;
create policy services_owner_write on public.services
  for all using (
    exists (select 1 from public.vendors v
            where v.vendor_id = services.vendor_id and v.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.vendors v
            where v.vendor_id = services.vendor_id and v.user_id = auth.uid())
  );

drop policy if exists services_admin_all on public.services;
create policy services_admin_all on public.services
  for all using (public.is_admin()) with check (public.is_admin());

-- service_images visibility defers to the parent service being readable.
drop policy if exists service_images_read on public.service_images;
create policy service_images_read on public.service_images
  for select using (
    exists (select 1 from public.services s
            where s.service_id = service_images.service_id)
  );

drop policy if exists service_images_owner_write on public.service_images;
create policy service_images_owner_write on public.service_images
  for all using (
    exists (
      select 1 from public.services s
      join public.vendors v on v.vendor_id = s.vendor_id
      where s.service_id = service_images.service_id and v.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.services s
      join public.vendors v on v.vendor_id = s.vendor_id
      where s.service_id = service_images.service_id and v.user_id = auth.uid()
    )
  );

drop policy if exists service_images_admin on public.service_images;
create policy service_images_admin on public.service_images
  for all using (public.is_admin()) with check (public.is_admin());
