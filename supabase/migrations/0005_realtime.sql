-- ============================================================================
-- Reparto :: Migration 0005 :: Enable Realtime
-- ----------------------------------------------------------------------------
-- The app subscribes to live changes on `notifications` (unread badge) and can
-- optionally listen to `orders`. Supabase Realtime only streams tables that are
-- members of the `supabase_realtime` publication.
--
-- Run this AFTER 0001-0004. Safe to run more than once.
-- ============================================================================

-- Ensure the publication exists (it does by default on Supabase, but be safe).
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

-- Add tables to the realtime publication (ignore if already added).
do $$
begin
  begin
    alter publication supabase_realtime add table public.notifications;
  exception when duplicate_object then null; end;

  begin
    alter publication supabase_realtime add table public.orders;
  exception when duplicate_object then null; end;
end $$;

-- Make sure full row data is available to realtime/RLS filters.
alter table public.notifications replica identity full;
alter table public.orders replica identity full;
