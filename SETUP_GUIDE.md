# Reparto — Dashboard & External Setup Guide

This guide covers everything you do **outside the code**: the Supabase
dashboard, Google OAuth, your `.env` file, creating an admin, and running the
app. Follow it top to bottom the first time. ⏱ ~20–30 minutes.

---

## Checklist (tick as you go)

- [ ] 1. Create a Supabase project
- [ ] 2. Run the 5 SQL migrations
- [ ] 3. Copy your API keys into `.env`
- [ ] 4. Configure Email auth (verification + redirect URLs)
- [ ] 5. (Optional) Configure Google sign-in
- [ ] 6. (Optional) Create a Storage bucket for product images
- [ ] 7. Install Flutter & run the app
- [ ] 8. Create your first admin
- [ ] 9. Smoke-test the flows

---

## 1. Create a Supabase project

1. Go to <https://supabase.com> → **Sign in** → **New project**.
2. Pick an **Organization**, set:
   - **Name**: `reparto`
   - **Database Password**: choose a strong one and **save it** (you'll need it
     for `psql`/CLI; not needed for the app).
   - **Region**: closest to your users (e.g. *West EU (London)* or *Africa* if
     available).
3. Click **Create new project** and wait ~2 minutes for it to provision.

---

## 2. Run the SQL migrations

**Dashboard way (easiest):**

1. Left sidebar → **SQL Editor** → **+ New query**.
2. Open `supabase/migrations/0001_schema.sql`, copy ALL of it, paste, click
   **Run** (or `Ctrl/Cmd + Enter`). You should see *"Success. No rows returned."*
3. Repeat **in order** for:
   - `0002_functions_triggers.sql`
   - `0003_rls.sql`
   - `0004_seed.sql`
   - `0005_realtime.sql`

> ⚠️ Order matters. 0002 depends on 0001's tables, 0003 depends on 0002's
> helper functions, etc.

**Verify it worked:**
- Sidebar → **Table Editor** → you should see 11 tables.
- Open `campuses` → it should have 4 seeded rows.
- Open `categories` → 6 seeded rows.

**CLI way (optional, if you prefer):**
```bash
# Settings → Database → Connection string (URI). Then:
export DB="postgresql://postgres:[YOUR-DB-PASSWORD]@db.[ref].supabase.co:5432/postgres"
for f in supabase/migrations/000*.sql; do echo "Running $f"; psql "$DB" -f "$f"; done
```

---

## 3. Get your API keys → `.env`

1. Sidebar → **Project Settings** (gear icon) → **API**.
2. Copy two values:
   - **Project URL** → e.g. `https://abcdxyz.supabase.co`
   - **Project API keys → `anon` `public`** → a long `eyJ...` string.
3. In the project root:
   ```bash
   cp .env.example .env
   ```
4. Edit `.env`:
   ```
   SUPABASE_URL=https://abcdxyz.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJI...your-anon-key...
   ```

> ✅ The **anon** key is safe to ship in a client app — RLS is what protects
> your data. **Never** put the `service_role` key in the app.

---

## 4. Configure Email auth

Sidebar → **Authentication** → **Providers** → **Email**:

- **Confirm email**: leave **ON** for production (matches the spec's "Email
  verification is mandatory"). For fast local testing you may turn it **OFF**
  so accounts work instantly without clicking an email link.
- Click **Save**.

Then **Authentication** → **URL Configuration**:

- **Site URL**: `http://localhost:port` while developing on web (Flutter prints
  the actual port, e.g. `http://localhost:5000`). For production use your real
  domain.
- **Redirect URLs** — add these (one per line):
  ```
  http://localhost:3000
  http://localhost:5000
  io.reparto.app://login-callback/
  ```
  (Add your production URL later too.)
- **Save**.

> 📧 The default Supabase email sender is rate-limited and fine for testing.
> For real volume, set up **Authentication → Emails → SMTP** with your own
> provider (e.g. Resend, SendGrid, Mailgun).

---

## 5. (Optional) Google Sign-In

Skip this if you only need email/password for now — the app works without it.

### 5a. Google Cloud Console
1. Go to <https://console.cloud.google.com> → create/select a project.
2. **APIs & Services** → **OAuth consent screen** → choose **External** →
   fill app name, support email, save (you can keep it in "Testing" mode and add
   your own email as a test user).
3. **APIs & Services** → **Credentials** → **+ Create Credentials** →
   **OAuth client ID**:
   - For **Web**: Application type = *Web application*. Under **Authorized
     redirect URIs**, add the Supabase callback (find it in the next step):
     ```
     https://[your-ref].supabase.co/auth/v1/callback
     ```
   - Click **Create** and copy the **Client ID** and **Client secret**.

### 5b. Supabase
1. Sidebar → **Authentication** → **Providers** → **Google** → toggle **Enable**.
2. Paste the **Client ID** and **Client Secret** from Google.
3. Copy the **Callback URL** shown there and make sure it's in your Google
   "Authorized redirect URIs" (step 5a).
4. **Save**.

### 5c. App side (already wired)
- Android deep link `io.reparto.app://login-callback/` is already declared in
  `android/app/src/main/AndroidManifest.xml`.
- First-time Google users are automatically routed to the **Select Campus**
  screen by the app.

---

## 6. (Optional) Storage bucket for product images

The app currently stores an **image URL** for products. If you want real uploads
later:

1. Sidebar → **Storage** → **New bucket** → name `product-images` → set
   **Public** = ON (so image URLs render) → **Create**.
2. Add a policy (Storage → Policies → New policy) allowing authenticated users
   to upload, public to read. (Implementing the Flutter upload UI is a
   documented next step.)

For now you can simply paste any public image URL in the product form.

---

## 7. Install Flutter & run

1. Install Flutter: <https://docs.flutter.dev/get-started/install> then verify:
   ```bash
   flutter doctor
   ```
2. From the project root:
   ```bash
   flutter pub get
   ```
3. If the `android/` or `web/` folders ever need regenerating:
   ```bash
   flutter create . --platforms=android,web --org io.reparto
   ```
   (The provided configs already match `io.reparto.app`.)
4. Run it:
   ```bash
   flutter run -d chrome          # Web
   flutter devices                # list connected Android devices/emulators
   flutter run -d <device-id>     # Android
   ```

> If you see the **"Reparto is not configured"** screen, your `.env` is missing
> or still has placeholder values — fix step 3 and restart.

---

## 8. Create your first admin

Admins can't self-register (per spec). So:

1. Run the app, **register a normal account** (e.g. student) with the email you
   want to be admin, and verify it if email confirmation is on.
2. In Supabase → **SQL Editor**, run:
   ```sql
   update public.users set role = 'admin' where email = 'you@university.edu';
   ```
3. Sign out and sign back in — you'll land on the **Admin** dashboard.

---

## 9. Smoke-test (recommended order)

1. **Admin**: confirm the 4 seeded campuses show under *Campuses*; add one if
   you like.
2. **Vendor**: register a vendor (pick a campus) → you'll see *Awaiting
   Approval*.
3. **Admin** → *Vendors* tab → **Approve** that vendor.
4. **Vendor**: sign in → add a product (set price + quantity).
5. **Student**: register on the **same campus** → you should see that product on
   *Browse*. Add to cart → **Place Order**.
6. **Vendor**: see the new order → advance status `Accepted → Preparing → Ready
   → Completed`. Watch the student's notification badge update.
7. **Student**: after *Completed*, open the order → **Rate Vendor**.

If all 7 work, your backend, RLS, realtime, and app are correctly connected. 🎉

---

## Common gotchas

| Symptom | Fix |
|--------|-----|
| "Reparto is not configured" screen | `.env` missing/placeholder values → step 3, restart app |
| Login says "Email not confirmed" | Click the verification email, or turn off *Confirm email* (step 4) for testing |
| Student sees no products | Vendor must be **approved** AND on the **same campus** as the student |
| Notification badge never updates | Run `0005_realtime.sql`; ensure Realtime is enabled for your project |
| Google sign-in loops/fails | Redirect URLs mismatch — verify Supabase callback URL is in Google's authorized URIs and `io.reparto.app://login-callback/` is in Supabase Redirect URLs |
| "row violates row-level security policy" | You're acting as the wrong role (e.g. trying to add a product before approval) — expected; RLS is working |
| Can't create admin | You must promote an existing user via SQL (step 8); admins aren't self-registered |

---

© Reparto — external setup guide.
