-- ============================================================================
-- Campus Marketplace – Migration 0019 v1.0 FINAL
-- Store details • Post-registration KYC (Ghana Card OR Student ID)
-- Service expiration + authorization • Consent audit • Platform settings
-- ----------------------------------------------------------------------------
-- Base: 0001_schema + 0006_feature_upgrades + 0007_storage + ... + 0012_paid_checkout_delivery
-- Date: 2025-07-01
-- Policy: v1.0-2025-07
-- Service auth: GHS 30 / 30d – Launch Free Mode (fee = 0)
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Helper – updated_at trigger (fixes ERROR 42883)
-- 0001–0012 do NOT define public.set_updated_at()
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ============================================================================
-- 1. VENDORS – v1.0 store profile + post-registration KYC
-- Base 0006 already has:
--   logo_url, business_phone, momo_number, momo_network,
--   ghana_card_number, ghana_card_image_url, description
-- We ADD the net-new v1.0 fields, keep legacy KYC columns for back-compat
-- ============================================================================

ALTER TABLE public.vendors
  ADD COLUMN IF NOT EXISTS store_name TEXT,
  ADD COLUMN IF NOT EXISTS store_description TEXT,
  ADD COLUMN IF NOT EXISTS store_location TEXT,
  ADD COLUMN IF NOT EXISTS store_phone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp_number TEXT,
  ADD COLUMN IF NOT EXISTS hall_hostel TEXT,
  ADD COLUMN IF NOT EXISTS gps_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS gps_lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS working_days TEXT[] DEFAULT ARRAY['Mon','Tue','Wed','Thu','Fri']::TEXT[],
  ADD COLUMN IF NOT EXISTS opening_time TIME DEFAULT '08:00:00',
  ADD COLUMN IF NOT EXISTS closing_time TIME DEFAULT '20:00:00',
  ADD COLUMN IF NOT EXISTS is_closed_today BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS holiday_mode BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS delivery_radius_km INT DEFAULT 2,
  ADD COLUMN IF NOT EXISTS seller_bio TEXT,
  ADD COLUMN IF NOT EXISTS program_year TEXT,
  ADD COLUMN IF NOT EXISTS specialties TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS custom_note TEXT,

  -- v1.0 verification – separate from legacy ghana_card_number
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_type TEXT,
  ADD COLUMN IF NOT EXISTS verification_id_number TEXT,
  ADD COLUMN IF NOT EXISTS verification_front_url TEXT,
  ADD COLUMN IF NOT EXISTS verification_back_url TEXT,
  ADD COLUMN IF NOT EXISTS verification_selfie_url TEXT,
  ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verification_approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verification_rejected_reason TEXT,

  -- platform / consent
  ADD COLUMN IF NOT EXISTS platform_fee_rate NUMERIC(5,2) DEFAULT 5.00,
  ADD COLUMN IF NOT EXISTS consent_seller_agreement BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS consent_seller_agreement_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS consent_seller_agreement_version TEXT,
  ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT false,

  -- updated_at for set_updated_at trigger parity
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- constraints – add if missing
DO $$ BEGIN
  ALTER TABLE public.vendors ADD CONSTRAINT vendors_verification_type_chk
    CHECK (verification_type IS NULL OR verification_type IN ('ghana_card','student_id'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.vendors ADD CONSTRAINT vendors_verification_status_chk
    CHECK (verification_status IN ('unverified','pending','approved','rejected'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- backfills
UPDATE public.vendors SET store_name = business_name WHERE store_name IS NULL OR store_name = '';
UPDATE public.vendors SET store_description = description WHERE store_description IS NULL AND description IS NOT NULL;
UPDATE public.vendors SET store_phone = COALESCE(business_phone, phone_number) WHERE store_phone IS NULL;
UPDATE public.vendors SET whatsapp_number = COALESCE(business_phone, phone_number) WHERE whatsapp_number IS NULL;

-- Migrate legacy KYC (0006) → v1.0 verification – preserves existing approved sellers
UPDATE public.vendors
SET
  verification_type = 'ghana_card',
  verification_id_number = ghana_card_number,
  verification_front_url = ghana_card_image_url,
  verification_status = CASE WHEN approval_status = 'approved' THEN 'approved' ELSE 'unverified' END,
  is_verified = (approval_status = 'approved' AND ghana_card_number IS NOT NULL),
  verification_approved_at = CASE WHEN approval_status = 'approved' THEN created_at ELSE NULL END
WHERE ghana_card_number IS NOT NULL
  AND (verification_id_number IS NULL OR verification_status = 'unverified');

-- Frictionless onboarding: ensure Ghana Card NOT NULL is removed (0006 did NOT set NOT NULL, but be safe)
ALTER TABLE public.vendors ALTER COLUMN ghana_card_number DROP NOT NULL;

COMMENT ON COLUMN public.vendors.is_verified IS 'v1.0 Verified Student Seller – unlocks prepayment, badge, priority search';
COMMENT ON COLUMN public.vendors.verification_type IS 'v1.0 – ghana_card | student_id – post-registration KYC';
COMMENT ON COLUMN public.vendors.ghana_card_number IS 'LEGACY 0006 – retained for back-compat – use verification_id_number going forward';

-- indexes
CREATE INDEX IF NOT EXISTS idx_vendors_is_verified ON public.vendors(is_verified);
CREATE INDEX IF NOT EXISTS idx_vendors_verification_status ON public.vendors(verification_status);
CREATE INDEX IF NOT EXISTS idx_vendors_profile_completed ON public.vendors(profile_completed);

-- ============================================================================
-- 2. SERVICES – expiration + authorization
-- Base schema (from your Service model): service_id, vendor_id, title, description,
-- category, price, price_from, availability, location, image_url, status
-- ============================================================================

ALTER TABLE public.services
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_authorized BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS authorization_fee_paid NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS authorization_paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS authorization_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS consent_given BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS consent_given_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- backfill 14-day free listing
UPDATE public.services
SET expires_at = COALESCE(created_at, NOW()) + INTERVAL '14 days'
WHERE expires_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_services_expires_at ON public.services(expires_at);
CREATE INDEX IF NOT EXISTS idx_services_is_authorized ON public.services(is_authorized);
CREATE INDEX IF NOT EXISTS idx_services_status ON public.services(status);

-- ============================================================================
-- 3. PLATFORM_SETTINGS – NEW – singleton
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.platform_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_auth_fee NUMERIC(10,2) NOT NULL DEFAULT 0, -- 0 = Free Mode launch
  service_auth_duration_days INT NOT NULL DEFAULT 30,
  service_free_listing_days INT NOT NULL DEFAULT 14,
  platform_fee_seller_percent NUMERIC(5,2) NOT NULL DEFAULT 5.00,
  platform_fee_service_percent NUMERIC(5,2) NOT NULL DEFAULT 8.00,
  verification_required_for_prepayment BOOLEAN NOT NULL DEFAULT true,
  kyc_allowed_types TEXT[] NOT NULL DEFAULT ARRAY['ghana_card','student_id']::TEXT[],
  current_policy_version TEXT NOT NULL DEFAULT 'v1.0-2025-07',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.platform_settings (
  service_auth_fee, service_auth_duration_days, service_free_listing_days,
  platform_fee_seller_percent, platform_fee_service_percent,
  current_policy_version
)
SELECT 0, 30, 14, 5.00, 8.00, 'v1.0-2025-07'
WHERE NOT EXISTS (SELECT 1 FROM public.platform_settings);

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "platform_settings_read_all" ON public.platform_settings;
CREATE POLICY "platform_settings_read_all" ON public.platform_settings FOR SELECT USING (true);
DROP POLICY IF EXISTS "platform_settings_admin_write" ON public.platform_settings;
CREATE POLICY "platform_settings_admin_write" ON public.platform_settings FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- updated_at trigger – now safe, set_updated_at() exists (see top of file)
DROP TRIGGER IF EXISTS trg_platform_settings_updated ON public.platform_settings;
CREATE TRIGGER trg_platform_settings_updated
BEFORE UPDATE ON public.platform_settings
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- keep vendors.updated_at fresh too
DROP TRIGGER IF EXISTS trg_vendors_updated ON public.vendors;
CREATE TRIGGER trg_vendors_updated
BEFORE UPDATE ON public.vendors
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 4. CONSENT_RECORDS – NEW – Ghana DPA 2012 audit trail
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL
    CHECK (consent_type IN ('seller_agreement','service_post','payment_auth','verification_submit','checkout_policy','terms_update')),
  policy_version TEXT NOT NULL,
  consented_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT,
  metadata JSONB DEFAULT '{}'::JSONB,
  signature_hash TEXT,
  revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_consent_user_type ON public.consent_records(user_id, consent_type, consented_at DESC);

ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "consent_own_read" ON public.consent_records;
CREATE POLICY "consent_own_read" ON public.consent_records FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "consent_own_insert" ON public.consent_records;
CREATE POLICY "consent_own_insert" ON public.consent_records FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "consent_admin_read" ON public.consent_records;
CREATE POLICY "consent_admin_read" ON public.consent_records FOR SELECT USING (public.is_admin());

-- ============================================================================
-- 5. VERIFICATION_AUDIT_LOG – NEW
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.verification_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES public.vendors(vendor_id) ON DELETE CASCADE,
  admin_id UUID REFERENCES auth.users(id),
  old_status TEXT,
  new_status TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.verification_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "verification_audit_admin" ON public.verification_audit_log;
CREATE POLICY "verification_audit_admin" ON public.verification_audit_log
  FOR SELECT USING (public.is_admin());
CREATE POLICY "verification_audit_admin_insert" ON public.verification_audit_log
  FOR INSERT WITH CHECK (public.is_admin());

-- ============================================================================
-- 6. SERVICE expiration – cron safe – respects Free Mode
-- ============================================================================
CREATE OR REPLACE FUNCTION public.expire_unpaid_services()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fee NUMERIC;
  expired_count INT := 0;
BEGIN
  SELECT service_auth_fee INTO v_fee
  FROM public.platform_settings
  ORDER BY updated_at DESC
  LIMIT 1;

  IF COALESCE(v_fee,0) = 0 THEN
    RETURN 0; -- Free Mode – no expiration
  END IF;

  UPDATE public.services
  SET status = 'expired', updated_at = NOW()
  WHERE COALESCE(is_authorized,false) = false
    AND expires_at IS NOT NULL
    AND expires_at < NOW()
    AND status <> 'expired'::availability_status;

  GET DIAGNOSTICS expired_count = ROW_COUNT;
  RETURN expired_count;
END;
$$;

CREATE OR REPLACE VIEW public.active_services AS
SELECT s.*
FROM public.services s
CROSS JOIN LATERAL (
  SELECT service_auth_fee AS fee
  FROM public.platform_settings
  ORDER BY updated_at DESC
  LIMIT 1
) p
WHERE s.status = 'available'::availability_status
  AND (
    p.fee = 0
    OR COALESCE(s.is_authorized,false) = true
    OR s.expires_at IS NULL
    OR s.expires_at > NOW()
  );

-- ============================================================================
-- 7. RPCs – v1.0 flows
-- ============================================================================

-- 7a. vendor_update_store
CREATE OR REPLACE FUNCTION public.vendor_update_store(p_payload JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_vendor_id UUID;
BEGIN
  SELECT vendor_id INTO v_vendor_id FROM public.vendors WHERE user_id = auth.uid();
  IF v_vendor_id IS NULL THEN RAISE EXCEPTION 'vendor not found'; END IF;

  UPDATE public.vendors SET
    store_name = COALESCE(p_payload->>'store_name', store_name, business_name),
    store_description = p_payload->>'store_description',
    store_location = p_payload->>'store_location',
    store_phone = p_payload->>'store_phone',
    whatsapp_number = COALESCE(p_payload->>'whatsapp_number', whatsapp_number),
    hall_hostel = p_payload->>'hall_hostel',
    gps_lat = COALESCE((p_payload->>'gps_lat')::DOUBLE PRECISION, gps_lat),
    gps_lng = COALESCE((p_payload->>'gps_lng')::DOUBLE PRECISION, gps_lng),
    working_days = CASE WHEN p_payload ? 'working_days'
      THEN ARRAY(SELECT jsonb_array_elements_text(p_payload->'working_days'))
      ELSE working_days END,
    opening_time = COALESCE((p_payload->>'opening_time')::TIME, opening_time),
    closing_time = COALESCE((p_payload->>'closing_time')::TIME, closing_time),
    is_closed_today = COALESCE((p_payload->>'is_closed_today')::BOOLEAN, is_closed_today),
    holiday_mode = COALESCE((p_payload->>'holiday_mode')::BOOLEAN, holiday_mode),
    delivery_radius_km = COALESCE((p_payload->>'delivery_radius_km')::INT, delivery_radius_km),
    seller_bio = p_payload->>'seller_bio',
    program_year = p_payload->>'program_year',
    specialties = CASE WHEN p_payload ? 'specialties'
      THEN ARRAY(SELECT jsonb_array_elements_text(p_payload->'specialties'))
      ELSE specialties END,
    custom_note = p_payload->>'custom_note',
    profile_completed = COALESCE((p_payload->>'profile_completed')::BOOLEAN, true),
    updated_at = NOW()
  WHERE vendor_id = v_vendor_id;
END;
$$;

-- 7b. vendor_submit_verification – post-registration KYC
CREATE OR REPLACE FUNCTION public.vendor_submit_verification(p_payload JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_vendor_id UUID;
BEGIN
  SELECT vendor_id INTO v_vendor_id FROM public.vendors WHERE user_id = auth.uid();
  IF v_vendor_id IS NULL THEN RAISE EXCEPTION 'vendor not found'; END IF;

  UPDATE public.vendors SET
    verification_type = p_payload->>'verification_type',
    verification_id_number = p_payload->>'verification_id_number',
    verification_front_url = p_payload->>'verification_front_url',
    verification_back_url = p_payload->>'verification_back_url',
    verification_selfie_url = p_payload->>'verification_selfie_url',
    verification_status = 'pending',
    verification_submitted_at = NOW(),
    verification_rejected_reason = NULL,
    updated_at = NOW()
  WHERE vendor_id = v_vendor_id;
END;
$$;

-- 7c. admin_review_verification – grant verified badge
CREATE OR REPLACE FUNCTION public.admin_review_verification(
  p_vendor_id UUID,
  p_approve BOOLEAN,
  p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_admin UUID := auth.uid();
DECLARE v_old TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only';
  END IF;

  SELECT verification_status INTO v_old FROM public.vendors WHERE vendor_id = p_vendor_id;

  INSERT INTO public.verification_audit_log(vendor_id, admin_id, old_status, new_status, reason)
  VALUES (p_vendor_id, v_admin, v_old, CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END, p_reason);

  IF p_approve THEN
    UPDATE public.vendors SET
      verification_status = 'approved',
      is_verified = true,
      verification_approved_at = NOW(),
      approval_status = 'approved',
      verification_rejected_reason = NULL,
      updated_at = NOW()
    WHERE vendor_id = p_vendor_id;
  ELSE
    UPDATE public.vendors SET
      verification_status = 'rejected',
      is_verified = false,
      verification_rejected_reason = p_reason,
      updated_at = NOW()
    WHERE vendor_id = p_vendor_id;
  END IF;
END;
$$;

-- 7d. record_consent – DPA audit
CREATE OR REPLACE FUNCTION public.record_consent(
  p_consent_type TEXT,
  p_policy_version TEXT,
  p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO public.consent_records(
    user_id, consent_type, policy_version, metadata, signature_hash
  )
  VALUES (
    auth.uid(),
    p_consent_type,
    p_policy_version,
    COALESCE(p_metadata,'{}'::JSONB),
    encode(digest(
      auth.uid()::TEXT || p_consent_type || p_policy_version || clock_timestamp()::TEXT,
      'sha256'
    ),'hex')
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- grants
GRANT EXECUTE ON FUNCTION public.expire_unpaid_services() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.vendor_update_store(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendor_submit_verification(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_verification(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_consent(TEXT, TEXT, JSONB) TO authenticated;

-- ============================================================================
-- 8. Update handle_new_user() – v1.0 frictionless – REMOVE Ghana Card requirement
-- 0006 version inserts ghana_card_number at sign-up – replace with KYC-free version
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_campus UUID;
BEGIN
  BEGIN
    v_campus := nullif(new.raw_user_meta_data ->> 'campus_id', '')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_campus := null;
  END;

  INSERT INTO public.users (user_id, full_name, email, role, campus_id, profile_image)
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce((new.raw_user_meta_data ->> 'role')::user_role, 'student'),
    v_campus,
    new.raw_user_meta_data ->> 'avatar_url'
  )
  ON CONFLICT (user_id) DO NOTHING;

  -- v1.0 – vendor auto-create WITHOUT Ghana Card – KYC post-registration
  IF coalesce((new.raw_user_meta_data ->> 'role'), '') = 'vendor'
     AND (new.raw_user_meta_data ->> 'business_name') IS NOT NULL
     AND v_campus IS NOT NULL THEN
    INSERT INTO public.vendors
      (user_id, business_name, owner_name, phone_number, business_phone,
       momo_number, momo_network, campus_id, approval_status,
       is_verified, verification_status, consent_seller_agreement, profile_completed)
    VALUES (
      new.id,
      new.raw_user_meta_data ->> 'business_name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'phone_number',
      new.raw_user_meta_data ->> 'business_phone',
      new.raw_user_meta_data ->> 'momo_number',
      new.raw_user_meta_data ->> 'momo_network',
      v_campus,
      'pending',
      false,
      'unverified',
      false,
      false
    )
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN new;
END;
$$;

-- ============================================================================
-- 9. Storage – align v1.0 bucket names with 0007 kebab-case buckets
-- 0007 created: product-images, business-logos, kyc-documents
-- App code uses StorageService.kycDocuments etc. – policies already correct.
-- Add optional service-images bucket (falls back to product-images if missing)
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('service-images', 'service-images', true),
  ('store-logos', 'store-logos', true)
ON CONFLICT (id) DO NOTHING;

-- service-images – public read, owner write (same pattern as product-images)
DROP POLICY IF EXISTS "service_images_read" ON storage.objects;
CREATE POLICY "service_images_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'service-images');

DROP POLICY IF EXISTS "service_images_write" ON storage.objects;
CREATE POLICY "service_images_write" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'service-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
DROP POLICY IF EXISTS "service_images_update" ON storage.objects;
CREATE POLICY "service_images_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'service-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
DROP POLICY IF EXISTS "service_images_delete" ON storage.objects;
CREATE POLICY "service_images_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'service-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- store-logos – alias to business-logos – same policy
DROP POLICY IF EXISTS "store_logos_read" ON storage.objects;
CREATE POLICY "store_logos_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'store-logos');
DROP POLICY IF EXISTS "store_logos_write" ON storage.objects;
CREATE POLICY "store_logos_write" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- kyc-documents – ensure 0007 policies still allow front/back/selfie
-- 0007 already: owner read + admin read via public.is_admin()
-- No change needed – v1.0 uses same bucket: 'kyc-documents'
-- App-side constant mapping:
--   StorageService.kycDocuments    -> 'kyc-documents'
--   StorageService.businessLogos   -> 'business-logos'  (also 'store-logos' accepted)
--   StorageService.productImages   -> 'product-images' (also 'service-images')

COMMIT;

-- ============================================================================
-- Post-migration verification
-- ============================================================================
-- SELECT column_name FROM information_schema.columns WHERE table_name='vendors' AND column_name LIKE 'verif%' OR column_name LIKE 'store_%' OR column_name LIKE '%is_verified%';
-- SELECT * FROM platform_settings;  -- service_auth_fee should = 0  (Free Mode)
-- SELECT public.expire_unpaid_services(); -- should return 0 in Free Mode
--
-- Legacy KYC data migrated?
-- SELECT business_name, ghana_card_number, verification_id_number, is_verified, verification_status
-- FROM vendors WHERE ghana_card_number IS NOT NULL;
-- → verification_id_number should be backfilled, is_verified = (approval_status='approved')
-- ============================================================================
