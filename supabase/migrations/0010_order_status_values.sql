-- ============================================================================
-- Reparto :: Migration 0010 :: Extend order_status enum (delivery flow)
-- ----------------------------------------------------------------------------
-- Adds the delivery-oriented lifecycle stages requested for Reparto:
--   pending(Placed) -> confirmed -> dispatched -> delivered  (+ cancelled)
--
-- NOTE: Postgres requires new enum values to be committed BEFORE they are used,
-- so these live in their own migration. Run this file on its own, then run
-- 0011. Safe to run more than once.
-- ============================================================================

alter type order_status add value if not exists 'confirmed';
alter type order_status add value if not exists 'dispatched';
alter type order_status add value if not exists 'delivered';
