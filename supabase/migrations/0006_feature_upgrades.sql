-- ============================================================================
-- Reparto :: Migration 0006 :: Feature Upgrades
--   • Vendor KYC fields (Ghana Card, business phone, mobile money)
--   • Logo / image columns
--   • Payments table (Paystack)
--   • Device tokens (FCM push)
--   • Order payment status
-- ----------------------------------------------------------------------------
-- Run AFTER 0001-0005. Safe to run more than once.
-- ============================================================================

-- ---- Enums -----------------------------------------------------------------
do $$ begin
  create type payment_status as enum ('pending', 'paid', 'failed', 'refunded');
exception when duplicate_object then null; end $$;

-- ---- Vendors: business profile + KYC ---------------------------------------
alter table public.vendors
  add column if not exists logo_url            text,
  add column if not exists business_phone      text,            -- business contact line
  add column if not exists momo_number         text,            -- mobile money (payout)
  add column if not exists momo_network        text,            -- MTN / Vodafone / AirtelTigo
  add column if not exists ghana_card_number   text,            -- GHA-XXXXXXXXX-X
  add column if not exists ghana_card_image_url text,           -- private bucket path
  add column if not exists description         text;

-- Validate Ghana Card format when present (GHA-#########-#).
do $$ begin
  alter table public.vendors
    add constraint vendors_ghana_card_format
    check (
      ghana_card_number is null
      or ghana_card_number ~ '^GHA-[0-9]{9}-[0-9]$'
    );
exception when duplicate_object then null; end $$;

-- ---- Orders: payment tracking ----------------------------------------------
alter table public.orders
  add column if not exists payment_status   payment_status not null default 'pending',
  add column if not exists payment_reference text;

-- ---- Payments table --------------------------------------------------------
create table if not exists public.payments (
  payment_id   uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.users(user_id) on delete cascade,
  reference    text not null unique,                 -- Paystack reference
  amount       numeric(12,2) not null check (amount >= 0),
  currency     text not null default 'GHS',
  status       payment_status not null default 'pending',
  channel      text,                                  -- card / mobile_money / ...
  metadata     jsonb,
  created_at   timestamptz not null default now(),
  verified_at  timestamptz
);
create index if not exists idx_payments_student on public.payments(student_id);
create index if not exists idx_payments_ref      on public.payments(reference);

-- ---- Device tokens (FCM) ---------------------------------------------------
create table if not exists public.device_tokens (
  token        text primary key,
  user_id      uuid not null references public.users(user_id) on delete cascade,
  platform     text,                                  -- android / ios / web
  created_at   timestamptz not null default now()
);
create index if not exists idx_device_tokens_user on public.device_tokens(user_id);

-- ============================================================================
-- RLS for new tables
-- ============================================================================
alter table public.payments      enable row level security;
alter table public.device_tokens enable row level security;

-- Payments: a student sees their own; admins see all. Writes happen via the
-- Edge Function (service role bypasses RLS), but allow the owner to insert a
-- pending record too.
drop policy if exists payments_owner_read on public.payments;
create policy payments_owner_read on public.payments
  for select using (student_id = auth.uid() or public.is_admin());

drop policy if exists payments_owner_insert on public.payments;
create policy payments_owner_insert on public.payments
  for insert with check (student_id = auth.uid());

-- Device tokens: a user manages only their own tokens.
drop policy if exists device_tokens_owner on public.device_tokens;
create policy device_tokens_owner on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- Vendor self-update policy refresh
-- The original vendors_self_update forbade changing approval_status; keep that
-- but make sure the new KYC columns are updatable by the owner.
-- (No change needed: the existing USING/WITH CHECK already scopes by user_id
--  and only locks approval_status via the equality trick.)
-- ============================================================================

-- Expand the new-user trigger so vendor KYC details captured at sign-up are
-- persisted on the auto-created vendor row.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campus uuid;
begin
  begin
    v_campus := nullif(new.raw_user_meta_data ->> 'campus_id', '')::uuid;
  exception when others then
    v_campus := null;
  end;

  insert into public.users (user_id, full_name, email, role, campus_id, profile_image)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce((new.raw_user_meta_data ->> 'role')::user_role, 'student'),
    v_campus,
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (user_id) do nothing;

  if coalesce((new.raw_user_meta_data ->> 'role'), '') = 'vendor'
     and (new.raw_user_meta_data ->> 'business_name') is not null
     and v_campus is not null then
    insert into public.vendors
      (user_id, business_name, owner_name, phone_number, business_phone,
       momo_number, momo_network, ghana_card_number, campus_id, approval_status)
    values (
      new.id,
      new.raw_user_meta_data ->> 'business_name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'phone_number',
      new.raw_user_meta_data ->> 'business_phone',
      new.raw_user_meta_data ->> 'momo_number',
      new.raw_user_meta_data ->> 'momo_network',
      nullif(new.raw_user_meta_data ->> 'ghana_card_number', ''),
      v_campus,
      'pending'
    )
    on conflict (user_id) do nothing;
  end if;

  return new;
end;
$$;
