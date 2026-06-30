# UjustBUY — Spec Pivot Plan (v1.0 spec → current app)

Source of truth: **UjustBUY Screen Specification v1.0** (H.O.B.O Services).
This document tracks the migration from the current build to that spec.

## Guiding decisions (confirmed with product owner)
1. **Full pivot** — the spec is the new source of truth.
2. **Backend is in scope** — schema, migrations, models, providers, routing, roles may change.
3. **Font/icons stay** — Inter + Material icons (DM Sans/lucide deferred; lucide breaks on Dart 3 because it extends the `final` `IconData`).
4. **Vendor = Student Seller** — *same backend logic, name change only.* We keep the
   `vendors` table, `vendor_id`, `role='vendor'`, and `vendor_product_stats` RPC as
   **internal identifiers** (exactly like we keep `reparto`/`io.reparto.app` internal
   while displaying "UjustBUY"). Only user-facing text becomes "Student Seller".

## Internal identifiers we DO NOT rename (to avoid breaking OAuth/DB/RPC)
- DB table `vendors`, column `vendor_id`
- `UserRole.vendor` enum value + `role='vendor'` string in Supabase
- RPC `vendor_product_stats`
- Provider/file names under `features/vendor/` (internal)

## Phases

### Phase 1 — Terminology rebrand (display only) — SAFE, no backend change
Rebrand user-facing "Vendor/Business" → "Student Seller" across the UI layer.
Status: **in progress**.

### Phase 2 — Money in pesewas (integer) — DONE (non-destructive variant)
**Engineering decision:** the DB already stores money as `numeric(12,2)`, which is
Postgres *exact decimal* (NOT floating point) — so the spec's stated reason for
pesewas ("prevent float errors") is already satisfied in storage. A destructive
column type change would also risk the Paystack `Math.round(total*100)` path
(double-charging customers 100×) and can't be tested in-sandbox. So instead:
- Added `lib/core/utils/money.dart` — integer-pesewa calc + `Money.format()` + a
  single conversion boundary (`fromCedis` / `toCedis` / `parse`).
- Added pesewa accessors to models (additive; double getters kept):
  `Product.pricePesewas`, `CartItem.lineTotalPesewas`,
  `OrderItem.unitPricePesewas/lineTotalPesewas`, `AppOrder.totalAmountPesewas`.
- `cartTotalPesewasProvider` now computes the cart total with **exact integer
  math** (the only real float-accumulation risk); `cartTotalProvider` derives
  cedis from it. Storage + Paystack flow untouched → zero live-charge risk.
- This gives P3 (commission tiers, spec-defined in pesewas) a clean foundation.

Deferred (optional, needs live DB + payment testing you run): converting the
actual `numeric` columns to integer pesewas. Not recommended given the above.

### Phase 3 — Commission tiers — DONE
- **Migration `0014_commission_tiers.sql`**: `commission_tiers` table (global rows
  with `campus_id IS NULL`; per-campus overrides), `commission_for_price(price,campus)`
  SQL function (pesewas, prefers campus tier then global), seeded with spec defaults,
  RLS (everyone reads, admins write), grants.
- **Dart**: `core/utils/commission.dart` (`CommissionTier` + client calculator that
  mirrors the SQL, with spec defaults as offline fallback); `commissionTiersProvider`
  (shared) + `adminCommissionTiersProvider`.
- **Surfaced platform fee** (transparent, display-only): Product Detail "Platform fee"
  section (C1); live "Platform fee for this price" line on the Product listing form (E2a).
- **Admin G3**: `admin_commission_screen.dart` — list tiers, add/edit/delete (flat GH₵
  or percent), GH₵ in → pesewas stored. Added as a 6th admin tab ("Commission").

**Deliberate scope boundary:** the fee is shown for transparency but is NOT yet added to
the Paystack charge or deducted from payout — `paystack-initialize` still charges items
only. Wiring commission into the actual charge + seller payout is **P6 (escrow)** so the
displayed total never mismatches the real charge. Documented to avoid a money bug.

#### How to apply 0014 (you run this — I can't here)
1. Supabase Dashboard → SQL Editor → paste `supabase/migrations/0014_commission_tiers.sql` → Run.
   (Or `supabase db push` if using the CLI.) It's idempotent — safe to re-run.
2. Verify table + seed:
   `select price_from, price_to, flat_pesewas, percent_bps from public.commission_tiers order by price_from;`
   → 7 rows, GH501+ row has `percent_bps = 500`.
3. Verify the function:
   `select public.commission_for_price(4500, null);`  → `350`  (GH45 → GH3.50)
   `select public.commission_for_price(60000, null);` → `3000` (GH600 → 5% = GH30)
   `select public.commission_for_price(0, null);`     → `0`
4. In-app: open a product → "Platform fee" shows; on the listing form, type a price → fee updates live; Admin → Commission tab → add/edit/delete works.

### Phase 4 — Guest mode + sign-in interstitials — DONE
- **Migration `0015_guest_read_access.sql`**: lets the Supabase `anon` role READ the
  public catalogue (categories: all; vendors: approved; products: of approved sellers;
  product_images + reviews). This was the hidden blocker — old RLS required auth, so
  guests would have seen an empty app. All write paths stay authenticated/owner/admin.
- **Router** (`app_router.dart`): guests are no longer hard-redirected to /login.
  `/splash` → `/student`; guest-browsable routes (`/student`, `/student/product/:id`,
  `/student/shop/:id`, `/about`) are open; any other route for a guest falls back to
  `/student` (no hard block). Signed-in redirects unchanged.
- **H1 interstitial** `core/widgets/sign_in_prompt.dart` — contextual bottom sheet
  ("You need an account to …") with Sign In / Create Account / Continue Browsing.
- **`isGuestProvider`** added (auth_providers).
- **Guards wired**: student shell (Favorites/Cart/Orders tabs → prompt; app bar shows
  "Sign In" for guests instead of bell/profile); product card add-to-cart; favorite
  button; product detail Buy Now + Add to Cart. Checkout is route-protected.

Deferred within P4: H2 guest campus-selection bottom sheet (session-local campus) and
the WhatsApp "Contact seller" guard (no WhatsApp button exists in the app yet — it
arrives with P8). Guests currently see the merged feed per existing campus logic.

#### How to apply 0015 (you run this)
1. SQL Editor → paste `supabase/migrations/0015_guest_read_access.sql` → Run (idempotent).
2. Verify as anon: in an incognito browser (logged-out app), the Browse feed shows
   approved sellers' available products. Tapping Buy/Cart/Favorite/Sell/Orders shows the
   sign-in sheet. Signing in resumes normal flow.
3. Sanity SQL (as anon key): `select count(*) from products;` returns approved products.

### Phase 5 — Services marketplace — DONE (catalogue + browse/detail)
- **Migration `0016_services.sql`**: `service_category` enum (8 spec categories),
  `services` table (vendor-owned, campus-scoped via owner), `service_images` child;
  RLS mirrors products (guests + campus users read approved sellers' services;
  owner/admin write).
- **Dart**: `Service` model + `ServiceCategory` enum (db value + display label +
  `priceLabel`/`pricePesewas`); repo `fetchServices()/fetchService()`;
  `servicesProvider` (+ category/search state) and `serviceProvider` family.
- **Screens**: D2 `services_screen.dart` (category chips + list, shimmer/empty/error,
  staggered) and D1 `service_detail_screen.dart` (gallery, about/availability/location,
  seller card, action bar). Routes `/student/services`, `/student/service/:id` added and
  whitelisted for guests. A "Services" icon in the student app bar opens the browse.
- WhatsApp "Contact" works (url_launcher), guarded for guests via the H1 sheet.

**Deliberately deferred (depend on other phases):**
- **D3 Booking & Pay** → needs Paystack/escrow ⇒ **P6**. The detail screen shows a
  disabled "Booking soon" button instead of a dead pay button.
- **E2b Service listing form** + 2-active-service limit → pairs with the Sell
  type-chooser ⇒ **P8**.
- Full bottom-nav restructure (Home/Search/Sell/Services/Profile) → **P8**; for now
  Services is reached via the app-bar icon to avoid destabilising the 5-tab shell.

#### How to apply 0016 (you run this)
1. SQL Editor → paste `supabase/migrations/0016_services.sql` → Run (idempotent).
2. Insert a test row (replace the vendor_id with a real APPROVED vendor):
   `insert into public.services (vendor_id, title, category, price, price_from, availability, location)
    values ('<approved-vendor-uuid>', 'Professional Haircut & Fade', 'hair_grooming', 20, false, 'Weekdays after 4pm', 'Unity Hall, Room 204');`
3. In-app: tap the Services icon (app bar) → the service shows; open it → detail renders;
   Contact on WhatsApp works (guests get the sign-in sheet).

### Phase 6 — Escrow + disputes — DONE
**Escrow model = status-based** (no separate funds ledger): money is conceptually
held while an order is paid + not completed, and "released" when it reaches
`completed`. This is fully additive — it does NOT touch the Paystack charge path,
so there is no double-charge risk. (Commission deduction at charge-time + actual
payout transfers remain out of scope by design; revenue/earnings already derive
from order status.)

- **Migration `0018_escrow_disputes.sql`**:
    - `order_status` += `disputed`; `orders.completed_at` + `orders.auto_release_at`.
    - Trigger `stamp_delivery_deadline` sets the 48h window when an order hits
      `delivered`.
    - `confirm_receipt(order)` — buyer releases funds → `completed`, notifies seller,
      and calls `reward_first_transaction` (the P7 tie-off: referrer +3 on the
      buyer's first completed order).
    - `auto_release_due_orders()` — completes delivered orders past their 48h window;
      optional `pg_cron` schedule included (commented) — until enabled, instant
      Confirm-Receipt still works; only the automatic fallback needs the job.
    - `disputes` table + `dispute_status` enum; `raise_dispute(...)` (validates state
        + ≥30 char description, flips order to `disputed`, notifies admins);
          `resolve_dispute(dispute, outcome, note)` (admin-only; refund_buyer/partial →
          cancelled, release_seller → completed; notifies buyer). All writes via
          SECURITY DEFINER; RLS lets buyer/seller/admin read.
- **Dart**: `OrderStatus.disputed` (+ label/fromDb/color/icon/isActive, and the
  timeline switch); `Dispute` model; student repo `confirmReceipt` + `raiseDispute`;
  admin repo `fetchDisputes` + `resolveDispute`; `adminDisputesProvider`.
- **Screens**: buyer Order Detail now shows **Confirm Receipt** (when delivered) +
  **Raise a Dispute**; C5 `dispute_form_screen.dart`; G4 `admin_disputes_screen.dart`
  reached via a gavel icon in the admin app bar.

**Still out of scope (intentional, documented):** charge-time commission split,
real Paystack payout transfers, and the cash dual-confirm C3b screen (the COD path
completes via the same Confirm-Receipt action). These move real money / need live
Paystack testing you control; revisit with live keys + a staging project.

#### How to apply 0018 (you run this)
1. SQL Editor → paste `supabase/migrations/0018_escrow_disputes.sql` → Run (idempotent).
2. (Optional) Database → Extensions → enable `pg_cron`, then uncomment the
   `cron.schedule(...)` block at the bottom for automatic 48h release.
3. Verify: mark an order `delivered` (seller) → buyer Order Detail shows "Confirm
   Receipt"; tapping it → order `completed`, seller notified. Raising a dispute on an
   active order → status `disputed`, appears in Admin → gavel icon → resolve.

### Phase 7 — Referral tokens — DONE
- **Migration `0017_referral_tokens.sql`**:
    - `users.referral_code` (unique, backfilled); additive `products.boosted_until` +
      `products.commission_waived` so redemptions actually do something.
    - `referrals` edge table (self-referral blocked by CHECK + function); `token_transactions`
      ledger (earned rows carry a 6-month `expires_at`; redeemed rows don't).
    - Functions: `token_balance()` (excludes expired), `_award_tokens()`, `claim_referral(code)`
      (+5 referrer / +2 newcomer; rejects self/duplicate silently),
      `reward_first_transaction(user)` (+3 on first completed order — call site lands in P6),
      `redeem_listing_boost()` (−10 → 3-day boost), `redeem_commission_discount()` (−5 → waive).
      All SECURITY DEFINER with internal balance checks (race-safe). RLS: users read only
      their own ledger/referrals; all writes via the functions.
- **Dart**: `TokenTransaction` model + `AppUser.referralCode`; `TokensRepository`;
  `tokenBalanceProvider` / `tokenHistoryProvider`.
- **F7 Referral Hub** (`referral_hub_screen.dart`): balance card, referral link (copy +
  WhatsApp share), how-it-works, redemption cards (enabled by balance), token history
  (earn green / redeem red / expired greyed). Route `/referrals`; entry added to both the
  student and seller profile menus.

**Deferred (depend on other phases):**
- Calling `reward_first_transaction()` on first completed order → wire in **P6**.
- Deep-link `/i/:code` handler that calls `claimReferral()` on signup → **P8**
  (repo method already exists; just needs the route + post-signup hook).
- Redeem buttons in the hub point users to the per-listing Manage screen action; the
  actual `redeemBoost`/`redeemCommissionDiscount` calls get wired to the Manage Listing
  "Boost with tokens" control in **P8** (E3).

#### How to apply 0017 (you run this)
1. SQL Editor → paste `supabase/migrations/0017_referral_tokens.sql` → Run (idempotent).
2. Verify: `select referral_code from public.users limit 5;` (all populated).
   `select public.token_balance();` (as a signed-in user → 0 initially).
3. Test claim (as user B, with user A's code):
   `select public.claim_referral('<A_CODE>');` → true; then
   `select public.token_balance();` as A → 5, as B → 2. Re-running returns false.
4. In-app: Profile → Referral Hub shows balance, link, history.

### Phase 8 — Onboarding + Sell flow + deferred tie-offs — DONE
- **Token redemptions wired (completes P7)**: vendor Products popup now has
  "Boost (10 tokens)" + "Waive commission (5 tokens)" → calls
  `redeem_listing_boost` / `redeem_commission_discount`, refreshes balance.
  Referral Hub gained an "Enter referral code" action → `claim_referral` (manual
  fallback since deep links need native config we can't set here).
- **Service creation E2b (completes P5)**: `service_form_screen.dart` (category,
  price + "starting from", availability, location, optional photos) + repo
  `upsertService/fetchMyServices/activeServiceCount/deleteService` +
  `myServicesProvider`. Route `/vendor/service-form`.
- **Sell type-chooser E1**: `sell_chooser.dart` bottom sheet (Product / Service);
  the seller FAB now opens it (was hard-wired to product form). The "Offer a
  Service" option disables at 2 active services (spec limit, informative).
- **Onboarding A2**: `onboarding_screen.dart` (3 value cards, Get Started / Sign In /
  Browse-without-account) at `/welcome` (whitelisted for guests).

**Still deferred (need native/live setup you control):**
- Deep-link `/i/:code` handler (Android intent filters + universal links) → claims
  referral automatically; the manual code entry covers it functionally meanwhile.
- Bottom-nav restructure to the exact spec 5 (Home/Search/Sell/Services/Profile) —
  current shell keeps its working tabs + a Services app-bar entry; cosmetic.
- **P6 (escrow/disputes/booking D3)** remains the one big unbuilt phase — flagged
  for joint review because it moves real money.

#### How to apply (nothing new to run for P8 — it uses 0016/0017 tables)
P8 is app-layer only. Ensure migrations **0014–0017** are applied. Then:
1. Seller → FAB → chooser → "Offer a Service" → fill + Post → appears in Services.
2. Seller → Products → ⋮ → Boost / Waive commission (needs ≥10 / ≥5 tokens).
3. Profile → Referral Hub → "Have a referral code?" → claim a friend's code.
4. Visit `/welcome` (e.g. from Login) to see onboarding.

## Migration apply order (all idempotent)
0014_commission_tiers → 0015_guest_read_access → 0016_services →
0017_referral_tokens.  (P6 will add 0018+ later, with your review.)

## Notes
- Each phase ships independently and is build-verifiable on its own.
- Phases 2–7 each touch Supabase migrations and RLS — review before deploy.
