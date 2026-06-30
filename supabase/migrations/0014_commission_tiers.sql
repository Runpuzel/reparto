-- ============================================================================
-- UjustBUY :: Migration 0014 :: Commission Tiers
-- ----------------------------------------------------------------------------
-- Flat commission determined by item price, looked up against a tier table.
-- Global tiers (campus_id IS NULL) apply everywhere; a row with a campus_id
-- overrides the global tier for that campus. All money is in INTEGER PESEWAS.
--
-- Spec defaults (per item price):
--   GH1-9     -> GH1.00      | GH10-20   -> GH2.00
--   GH21-50   -> GH3.50      | GH51-100  -> GH6.00
--   GH101-200 -> GH12.00     | GH201-500 -> GH25.00
--   GH501+    -> 5% of price | free items -> 0
--
-- Run AFTER 0013. Safe to run more than once (idempotent).
-- ============================================================================

-- ---- 1. Table --------------------------------------------------------------
create table if not exists public.commission_tiers (
  tier_id        uuid primary key default gen_random_uuid(),
  campus_id      uuid references public.campuses(campus_id) on delete cascade,
  -- inclusive price band in pesewas; price_to NULL = open-ended (top tier)
  price_from     integer not null check (price_from >= 0),
  price_to       integer check (price_to is null or price_to >= price_from),
  -- flat commission in pesewas (used when percent_bps is null)
  flat_pesewas   integer check (flat_pesewas is null or flat_pesewas >= 0),
  -- OR percentage in basis points (500 = 5%); used when flat_pesewas is null
  percent_bps    integer check (percent_bps is null or percent_bps >= 0),
  created_at     timestamptz not null default now(),
  -- exactly one of flat_pesewas / percent_bps must be set
  constraint commission_one_kind check (
    (flat_pesewas is not null and percent_bps is null)
    or (flat_pesewas is null and percent_bps is not null)
  )
);

create index if not exists idx_commission_campus
  on public.commission_tiers(campus_id);
create index if not exists idx_commission_band
  on public.commission_tiers(price_from, price_to);

-- ---- 2. Lookup: commission (pesewas) for a price (pesewas) on a campus ------
-- Prefers a campus-specific tier; falls back to the global tier. Free items
-- (price 0) always return 0. If no tier matches, returns 0 (safe default).
create or replace function public.commission_for_price(
  p_price_pesewas integer,
  p_campus_id     uuid default null
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r_tier record;
begin
  if p_price_pesewas is null or p_price_pesewas <= 0 then
    return 0;
  end if;

  -- Campus override first, then global (campus_id is null), nearest band first.
  select * into r_tier
  from public.commission_tiers t
  where t.price_from <= p_price_pesewas
    and (t.price_to is null or t.price_to >= p_price_pesewas)
    and (t.campus_id = p_campus_id or t.campus_id is null)
  order by (t.campus_id is not null) desc, t.price_from desc
  limit 1;

  if r_tier is null then
    return 0;
  end if;

  if r_tier.flat_pesewas is not null then
    return r_tier.flat_pesewas;
  end if;

  -- percentage (basis points), rounded to nearest pesewa
  return round(p_price_pesewas * r_tier.percent_bps / 10000.0)::integer;
end;
$$;

-- ---- 3. Seed global defaults (only if no global tiers exist yet) ------------
insert into public.commission_tiers
  (campus_id, price_from, price_to, flat_pesewas, percent_bps)
select * from (values
  (null::uuid,   100,   900,   100,  null::integer),  -- GH1-9    -> GH1.00
  (null::uuid,  1000,  2000,   200,  null::integer),  -- GH10-20  -> GH2.00
  (null::uuid,  2100,  5000,   350,  null::integer),  -- GH21-50  -> GH3.50
  (null::uuid,  5100, 10000,   600,  null::integer),  -- GH51-100 -> GH6.00
  (null::uuid, 10100, 20000,  1200,  null::integer),  -- GH101-200-> GH12.00
  (null::uuid, 20100, 50000,  2500,  null::integer),  -- GH201-500-> GH25.00
  (null::uuid, 50100,  null,  null,  500)             -- GH501+   -> 5%
) as seed(campus_id, price_from, price_to, flat_pesewas, percent_bps)
where not exists (
  select 1 from public.commission_tiers where campus_id is null
);

-- ---- 4. RLS ----------------------------------------------------------------
alter table public.commission_tiers enable row level security;

drop policy if exists commission_read on public.commission_tiers;
create policy commission_read on public.commission_tiers
  for select using (true);

drop policy if exists commission_admin_write on public.commission_tiers;
create policy commission_admin_write on public.commission_tiers
  for all using (public.is_admin()) with check (public.is_admin());

-- ---- 5. Grants -------------------------------------------------------------
grant execute on function public.commission_for_price(integer, uuid) to anon, authenticated;
