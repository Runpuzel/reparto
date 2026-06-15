-- ============================================================================
-- Reparto :: Campus Marketplace System
-- Migration 0001 :: Core Schema
-- ----------------------------------------------------------------------------
-- PostgreSQL (Supabase). Run in order: 0001 -> 0002 -> 0003 -> 0004.
-- ============================================================================

-- Extensions ----------------------------------------------------------------
create extension if not exists "pgcrypto";

-- Enumerated types ----------------------------------------------------------
do $$ begin
  create type user_role as enum ('student', 'vendor', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type campus_status as enum ('active', 'inactive');
exception when duplicate_object then null; end $$;

do $$ begin
  create type approval_status as enum ('pending', 'approved', 'rejected', 'suspended');
exception when duplicate_object then null; end $$;

do $$ begin
  create type availability_status as enum ('available', 'unavailable');
exception when duplicate_object then null; end $$;

do $$ begin
  create type order_status as enum
    ('pending', 'accepted', 'preparing', 'ready_for_pickup', 'completed', 'cancelled');
exception when duplicate_object then null; end $$;

-- ============================================================================
-- Campuses
-- ============================================================================
create table if not exists public.campuses (
  campus_id    uuid primary key default gen_random_uuid(),
  campus_name  text not null,
  location     text,
  status       campus_status not null default 'active',
  created_at   timestamptz not null default now()
);

-- ============================================================================
-- Users (profile table linked 1:1 to auth.users)
-- ============================================================================
create table if not exists public.users (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  full_name     text not null,
  email         text not null unique,
  role          user_role not null default 'student',
  campus_id     uuid references public.campuses(campus_id) on delete set null,
  profile_image text,
  is_suspended  boolean not null default false,
  created_at    timestamptz not null default now()
);

-- ============================================================================
-- Vendors
-- ============================================================================
create table if not exists public.vendors (
  vendor_id       uuid primary key default gen_random_uuid(),
  user_id         uuid not null unique references public.users(user_id) on delete cascade,
  business_name   text not null,
  owner_name      text,
  phone_number    text,
  approval_status approval_status not null default 'pending',
  campus_id       uuid not null references public.campuses(campus_id) on delete cascade,
  created_at      timestamptz not null default now()
);

-- ============================================================================
-- Categories
-- ============================================================================
create table if not exists public.categories (
  category_id   uuid primary key default gen_random_uuid(),
  category_name text not null unique,
  description   text
);

-- ============================================================================
-- Products
-- ============================================================================
create table if not exists public.products (
  product_id          uuid primary key default gen_random_uuid(),
  vendor_id           uuid not null references public.vendors(vendor_id) on delete cascade,
  category_id         uuid references public.categories(category_id) on delete set null,
  product_name        text not null,
  description         text,
  price               numeric(12,2) not null check (price >= 0),
  quantity_available  integer not null default 0 check (quantity_available >= 0),
  image_url           text,
  availability_status availability_status not null default 'available',
  created_at          timestamptz not null default now()
);

-- ============================================================================
-- Carts + Cart Items
-- ============================================================================
create table if not exists public.carts (
  cart_id    uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.users(user_id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.cart_items (
  cart_item_id uuid primary key default gen_random_uuid(),
  cart_id      uuid not null references public.carts(cart_id) on delete cascade,
  product_id   uuid not null references public.products(product_id) on delete cascade,
  quantity     integer not null default 1 check (quantity > 0),
  unique (cart_id, product_id)
);

-- ============================================================================
-- Orders + Order Items
-- ============================================================================
create table if not exists public.orders (
  order_id     uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.users(user_id) on delete cascade,
  vendor_id    uuid not null references public.vendors(vendor_id) on delete cascade,
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  order_status order_status not null default 'pending',
  created_at   timestamptz not null default now()
);

create table if not exists public.order_items (
  order_item_id uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders(order_id) on delete cascade,
  product_id    uuid references public.products(product_id) on delete set null,
  quantity      integer not null check (quantity > 0),
  unit_price    numeric(12,2) not null check (unit_price >= 0)
);

-- ============================================================================
-- Reviews
-- ============================================================================
create table if not exists public.reviews (
  review_id  uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.users(user_id) on delete cascade,
  vendor_id  uuid not null references public.vendors(vendor_id) on delete cascade,
  order_id   uuid references public.orders(order_id) on delete set null,
  rating     integer not null check (rating between 1 and 5),
  comment    text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- Notifications
-- ============================================================================
create table if not exists public.notifications (
  notification_id uuid primary key default gen_random_uuid(),
  recipient_id    uuid not null references public.users(user_id) on delete cascade,
  title           text not null,
  body            text,
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);

-- ============================================================================
-- Indexes
-- ============================================================================
create index if not exists idx_users_campus       on public.users(campus_id);
create index if not exists idx_vendors_campus      on public.vendors(campus_id);
create index if not exists idx_vendors_user        on public.vendors(user_id);
create index if not exists idx_products_vendor     on public.products(vendor_id);
create index if not exists idx_products_category   on public.products(category_id);
create index if not exists idx_cart_items_cart     on public.cart_items(cart_id);
create index if not exists idx_orders_student      on public.orders(student_id);
create index if not exists idx_orders_vendor       on public.orders(vendor_id);
create index if not exists idx_order_items_order   on public.order_items(order_id);
create index if not exists idx_reviews_vendor      on public.reviews(vendor_id);
create index if not exists idx_notifications_recip on public.notifications(recipient_id);
