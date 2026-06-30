-- ============================================================================
-- UjustBUY :: Migration 0017 :: Referral Tokens
-- ----------------------------------------------------------------------------
-- Spec PART ONE "Referral Tokens":
--   • referrer +5, new user +2 (welcome) on registration via a referral link
--   • referrer +3 when the referred user completes their FIRST transaction
--   • redeem: 10 tokens -> 3-day listing boost; 5 tokens -> commission discount
--     on one listing
--   • tokens expire 6 months after earning; not transferable; campus-scoped
--   • self-referrals rejected
--
-- Run AFTER 0016. Idempotent.
-- ============================================================================

-- ---- 1. Referral code on each user ----------------------------------------
alter table public.users
  add column if not exists referral_code text unique;

-- Backfill codes for existing users (8-char upper alnum from the uuid).
update public.users
   set referral_code = upper(substr(replace(user_id::text, '-', ''), 1, 8))
 where referral_code is null;

-- ---- 2. Additive listing effect columns (so redemptions DO something) ------
alter table public.products
  add column if not exists boosted_until     timestamptz,
  add column if not exists commission_waived boolean not null default false;

create index if not exists idx_products_boost on public.products(boosted_until);

-- ---- 3. Referral edges -----------------------------------------------------
create table if not exists public.referrals (
  referral_id   uuid primary key default gen_random_uuid(),
  referrer_id   uuid not null references public.users(user_id) on delete cascade,
  referred_id   uuid not null unique references public.users(user_id) on delete cascade,
  first_txn_rewarded boolean not null default false,
  created_at    timestamptz not null default now(),
  check (referrer_id <> referred_id)      -- no self-referral
);
create index if not exists idx_referrals_referrer on public.referrals(referrer_id);

-- ---- 4. Token ledger -------------------------------------------------------
-- Positive delta = earned (has expires_at); negative = redeemed (no expiry).
create table if not exists public.token_transactions (
  txn_id     uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(user_id) on delete cascade,
  delta      integer not null,
  reason     text not null,
  campus_id  uuid references public.campuses(campus_id) on delete set null,
  expires_at timestamptz,                 -- only for positive (earned) rows
  created_at timestamptz not null default now()
);
create index if not exists idx_tokens_user on public.token_transactions(user_id);

-- ---- 5. Balance (excludes expired earnings) --------------------------------
create or replace function public.token_balance(p_user uuid default auth.uid())
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(delta), 0)::integer
  from public.token_transactions
  where user_id = p_user
    and not (delta > 0 and expires_at is not null and expires_at <= now());
$$;

-- ---- 6. Award helper (internal) -------------------------------------------
create or replace function public._award_tokens(
  p_user uuid, p_amount integer, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_campus uuid;
begin
  select campus_id into v_campus from public.users where user_id = p_user;
  insert into public.token_transactions (user_id, delta, reason, campus_id, expires_at)
  values (p_user, p_amount, p_reason, v_campus,
          case when p_amount > 0 then now() + interval '6 months' else null end);
end;
$$;

-- ---- 7. Claim a referral (called once by the new user post-signup) ---------
-- Rewards referrer +5 and the caller +2. Self-referral / already-referred are
-- rejected silently (no error, no tokens).
create or replace function public.claim_referral(p_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me       uuid := auth.uid();
  v_referrer uuid;
begin
  if v_me is null or coalesce(trim(p_code), '') = '' then
    return false;
  end if;

  select user_id into v_referrer
  from public.users where referral_code = upper(trim(p_code));

  -- invalid code, self-referral, or already referred → no-op
  if v_referrer is null or v_referrer = v_me then
    return false;
  end if;
  if exists (select 1 from public.referrals where referred_id = v_me) then
    return false;
  end if;

  insert into public.referrals (referrer_id, referred_id) values (v_referrer, v_me);
  perform public._award_tokens(v_referrer, 5, 'Referral signup');
  perform public._award_tokens(v_me, 2, 'Welcome bonus');
  return true;
end;
$$;

-- ---- 8. First-transaction bonus (called from order completion in P6) -------
-- Awards the referrer +3 the first time their referred user completes an order.
create or replace function public.reward_first_transaction(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_ref record;
begin
  select * into v_ref from public.referrals
   where referred_id = p_user and first_txn_rewarded = false;
  if v_ref is null then return; end if;
  perform public._award_tokens(v_ref.referrer_id, 3, 'Referral first purchase');
  update public.referrals set first_txn_rewarded = true
   where referral_id = v_ref.referral_id;
end;
$$;

-- ---- 9. Redemptions (atomic balance check inside the function) -------------
create or replace function public.redeem_listing_boost(p_product uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid();
begin
  if not exists (
    select 1 from public.products p
    join public.vendors v on v.vendor_id = p.vendor_id
    where p.product_id = p_product and v.user_id = v_me
  ) then
    raise exception 'You can only boost your own listing';
  end if;
  if public.token_balance(v_me) < 10 then
    raise exception 'Not enough tokens (need 10)';
  end if;
  perform public._award_tokens(v_me, -10, 'Listing boost');
  update public.products
     set boosted_until = now() + interval '3 days'
   where product_id = p_product;
  return true;
end;
$$;

create or replace function public.redeem_commission_discount(p_product uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid();
begin
  if not exists (
    select 1 from public.products p
    join public.vendors v on v.vendor_id = p.vendor_id
    where p.product_id = p_product and v.user_id = v_me
  ) then
    raise exception 'You can only discount your own listing';
  end if;
  if public.token_balance(v_me) < 5 then
    raise exception 'Not enough tokens (need 5)';
  end if;
  perform public._award_tokens(v_me, -5, 'Commission discount');
  update public.products set commission_waived = true where product_id = p_product;
  return true;
end;
$$;

-- ---- 10. RLS ---------------------------------------------------------------
alter table public.token_transactions enable row level security;
alter table public.referrals          enable row level security;

drop policy if exists tokens_self_read on public.token_transactions;
create policy tokens_self_read on public.token_transactions
  for select using (user_id = auth.uid() or public.is_admin());

drop policy if exists referrals_self_read on public.referrals;
create policy referrals_self_read on public.referrals
  for select using (
    referrer_id = auth.uid() or referred_id = auth.uid() or public.is_admin()
  );

-- (No client INSERT/UPDATE policies: all writes go through SECURITY DEFINER
--  functions above, which enforce the rules.)

-- ---- 11. Grants ------------------------------------------------------------
grant execute on function public.token_balance(uuid) to authenticated;
grant execute on function public.claim_referral(text) to authenticated;
grant execute on function public.redeem_listing_boost(uuid) to authenticated;
grant execute on function public.redeem_commission_discount(uuid) to authenticated;
