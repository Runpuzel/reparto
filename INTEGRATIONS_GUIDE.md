# Reparto — Integrations Guide (Payments · Push · Google · Uploads)

This guide covers the new external integrations. Do the **SQL migrations** and
**Storage** steps first (they're required); Paystack/Push/Google are optional
feature flags you can enable when ready.

---

## 0. Apply the new database migrations

In the Supabase **SQL Editor**, run these in order (after the original 0001–0005):

```
supabase/migrations/0006_feature_upgrades.sql   -- vendor KYC, payments, device_tokens
supabase/migrations/0007_storage.sql            -- storage buckets + policies
supabase/migrations/0008_paid_orders.sql        -- paid checkout RPC + push hook
supabase/migrations/0009_product_images.sql     -- multiple images per product
supabase/migrations/0010_order_status_values.sql      -- delivery status values
supabase/migrations/0011_orders_favorites_categories.sql -- delivery, favorites, COD checkout
supabase/migrations/0012_paid_checkout_delivery.sql   -- Paystack checkout w/ delivery details
```

Verify: **Storage** now shows buckets `product-images`, `business-logos`
(public) and `kyc-documents` (private). **Table Editor** shows `payments` and
`device_tokens`, and `vendors` has new columns (logo_url, business_phone,
momo_number, verification_id_number, …).

---

## 1. Image uploads (works immediately)

No extra config — buckets + RLS were created in `0007_storage.sql`. The app:
- Vendor **logo** & **product photos** → public buckets, URLs stored on the row.
- **Student ID photo** → private `kyc-documents` bucket; admins view it via a
  short-lived **signed URL** in the Vendors tab.

Files are stored under `<user-id>/<timestamp>.<ext>` so the storage policies
grant each user write access only to their own folder.

> Mobile permissions (camera/photos) are already declared in the Android
> manifest. On iOS add `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`
> to `ios/Runner/Info.plist` when you add the iOS target.

---

## 2. Google Sign-In (make it actually work)

The app uses `google_sign_in` to get a Google ID token, then exchanges it with
Supabase via `signInWithIdToken`. On web, Google requires every site origin
that launches sign-in to be registered on the Web OAuth client.

### Steps
1. **Supabase** → Authentication → Providers → **Google**: enable it.
2. **Google Cloud Console** → Credentials → create OAuth client IDs:
   - **Web application** client → copy its **Client ID** + **Secret** into the
     Supabase Google provider. This Web client ID is also your
     `GOOGLE_WEB_CLIENT_ID`.
   - In the same Web client, add each exact **Authorized JavaScript origin**:
     `https://ujustbuy.store`, your Netlify preview/custom domains, and local
     dev origins such as `http://localhost:5000` or `http://localhost:7357`.
     Origins include scheme + host + optional port only; do not add paths.
   - In **OAuth consent screen**, set the app name to **UjustBUY**.
   - **Android** client → set package name `io.reparto.app` and your signing
     SHA-1 (`./gradlew signingReport` or `keytool`).
3. Put the **Web client ID** in `.env`:
   ```
   GOOGLE_WEB_CLIENT_ID=1234567890-abcdef.apps.googleusercontent.com
   ```
4. Make sure these are in Supabase → Auth → URL Configuration → Redirect URLs:
   ```
   io.reparto.app://login-callback/
   <your web origin, e.g. http://localhost:5000>
   ```

First-time Google users are auto-routed to **Select Campus**.

---

## 3. Paystack payments

Flow: app → `paystack-initialize` (computes cart total, returns checkout URL) →
hosted Paystack page (WebView on mobile / new tab on web) → `paystack-verify`
(confirms payment, places the order via `place_order_from_cart_paid`).

### Steps
1. Create a Paystack account → Dashboard → **Settings → API Keys** → copy your
   **Secret key** (`sk_test_...`).
2. Deploy the Edge Functions and set the secret:
   ```bash
   supabase link --project-ref <ref>
   supabase secrets set PAYSTACK_SECRET_KEY=sk_test_xxxxx
   supabase functions deploy paystack-initialize
   supabase functions deploy paystack-verify
   ```
3. Enable the feature flag in `.env`:
   ```
   ENABLE_PAYMENTS=true
   ```
4. The checkout button now reads **"Pay & Order"**. Use Paystack
   [test cards](https://paystack.com/docs/payments/test-payments) (e.g. card
   `4084 0840 8408 4081`, any future expiry, CVV `408`).

> Security: the amount is always recomputed **server-side** from the cart; the
> order is created **only after** Paystack verifies the payment. The secret key
> never touches the app.

---

## 4. Push notifications (Firebase Cloud Messaging)

Flow: any `notifications` insert → DB trigger `dispatch_push` → `send-push` Edge
Function → FCM → device. In-app realtime badge keeps working regardless.

### 4a. Firebase project
1. <https://console.firebase.google.com> → **Add project**.
2. Add an **Android app** with package `io.reparto.app`; download
   `google-services.json` into `android/app/`.
3. (Web) Add a **Web app**; copy the config into
   `web/firebase-messaging-sw.js` and generate a **Web Push certificate (VAPID)**
   under Cloud Messaging.
4. (iOS, later) add an iOS app + APNs key.

### 4b. Enable the Gradle plugin
Uncomment the two `com.google.gms.google-services` lines in
`android/settings.gradle` and `android/app/build.gradle`.

### 4c. Service account for the Edge Function
1. Firebase Console → Project Settings → **Service accounts** → **Generate new
   private key** (downloads a JSON).
2. Set secrets from that JSON:
   ```bash
   supabase secrets set FCM_PROJECT_ID=your-project-id
   supabase secrets set FCM_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
   supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   supabase secrets set PUSH_FUNCTION_SECRET=$(openssl rand -hex 24)
   supabase functions deploy send-push
   ```
3. Tell the DB trigger where to send (SQL Editor, once):
   ```sql
   alter database postgres set "app.settings.push_function_url"
     = 'https://<ref>.functions.supabase.co/send-push';
   alter database postgres set "app.settings.push_function_key"
     = '<the PUSH_FUNCTION_SECRET value>';
   ```
   Then reconnect (the settings apply to new connections).
4. Enable the flag in `.env`:
   ```
   ENABLE_PUSH=true
   ```

The app registers the device token after login and removes it on sign-out.

---

## 5. Final `.env`

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
GOOGLE_WEB_CLIENT_ID=...apps.googleusercontent.com
ENABLE_PAYMENTS=true
ENABLE_PUSH=true
```

## Quick test matrix

| Feature | How to verify |
|---------|---------------|
| Logo upload | Register vendor → pick a logo → see it on vendor profile & admin list |
| Product image | Vendor adds product with photo → appears on Browse card |
| Student ID | Vendor submits number + photo → admin opens the ID document |
| Google sign-in | Tap "Continue with Google" → lands on dashboard / Select Campus |
| Paystack | Cart → "Pay & Order" → test card → order appears as paid |
| Push | Place order → vendor device gets a push (app in background) |
