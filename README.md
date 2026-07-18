# UjustBUY — Multi-Campus Marketplace

A mobile-first, campus-isolated marketplace connecting **students** and **campus
vendors**, with an **admin** console for oversight. Built with **Flutter**
(Android + Web) and **Supabase** (PostgreSQL, Auth, Realtime, Row-Level
Security).

This repository is a **foundation scaffold**: a clean, structured, runnable
starting point implementing the architecture and core flows described in the
project documentation. Extend it feature-by-feature.

---

## ✨ What's implemented

| Area | Status |
|------|--------|
| Email/password auth (student & vendor) + Google OAuth | ✅ |
| Campus selection at sign-up / first Google login | ✅ |
| Role-based routing (student / vendor / admin) | ✅ |
| **Student**: browse, search, filter by category, product & vendor detail, cart, checkout, order history, cancel, reviews | ✅ |
| **Vendor**: approval gate, dashboard/sales, product CRUD + inventory, incoming orders + lifecycle transitions | ✅ |
| **Admin**: platform reports, vendor approvals/suspension, campus management, user suspension | ✅ |
| Notifications (in-app + realtime unread badge) | ✅ |
| Campus isolation + role rules enforced in DB via **RLS** | ✅ |
| Order lifecycle, stock decrement, review-after-completion — server-side | ✅ |
| **Image uploads** — business logo, product photos, Student ID (private bucket) | ✅ |
| **Paystack payments** — secure server-verified checkout (Edge Functions) | ✅ |
| **Push notifications** — FCM via Edge Function + DB trigger | ✅ |
| **Google Sign-In** — native id-token flow on mobile, OAuth on web | ✅ |
| **Vendor KYC** — Student ID (number + photo), business phone, mobile money | ✅ |
| Refined **design system** + the 8 UI/UX principles (see `UX_PRINCIPLES.md`) | ✅ |

> 📘 New integration setup lives in **[INTEGRATIONS_GUIDE.md](INTEGRATIONS_GUIDE.md)**
> (payments, push, Google, uploads) and **[UX_PRINCIPLES.md](UX_PRINCIPLES.md)**.

> Push notifications (Firebase Cloud Messaging) and image upload to Supabase
> Storage are wired conceptually (image *URL* field is supported) but FCM
> integration is left as a documented next step.

---

## 🏗 Architecture (Three-Tier)

```
Presentation (Flutter)  →  Application logic (Riverpod + Supabase RPC/Edge)  →  Data (Postgres + RLS + Realtime)
```

```
lib/
├─ core/
│  ├─ config/        env + supabase client
│  ├─ constants/     enums, app constants
│  ├─ router/        GoRouter with auth/role redirects
│  ├─ theme/         Material 3 theme
│  ├─ utils/         validators, formatters
│  └─ widgets/       shared UI (logo, async views, empty/error states)
├─ models/           immutable data models
├─ features/
│  ├─ auth/          repository, providers, screens
│  ├─ student/       browse, cart, orders, profile, details
│  ├─ vendor/        dashboard, products, orders, profile, product form
│  ├─ admin/         reports, vendors, campuses, users
│  └─ shared/        cross-cutting providers + notifications
└─ main.dart
supabase/
└─ migrations/       0001 schema · 0002 functions/triggers · 0003 RLS · 0004 seed
```

---

## 🚀 Setup

### 1. Prerequisites
- Flutter SDK 3.19+ (`flutter doctor`)
- A Supabase project (https://supabase.com)

### 2. Configure the database
In the Supabase dashboard → **SQL Editor**, run the migrations **in order**:

```
supabase/migrations/0001_schema.sql
supabase/migrations/0002_functions_triggers.sql
supabase/migrations/0003_rls.sql
supabase/migrations/0004_seed.sql
supabase/migrations/0005_realtime.sql
```

> 📋 **New to the dashboard?** Follow the step-by-step **[SETUP_GUIDE.md](SETUP_GUIDE.md)**
> — it walks through every click in Supabase, Google OAuth, `.env`, creating an
> admin, and a smoke-test checklist.

Or with the Supabase CLI:

```bash
supabase db push        # if you link the project & move these into supabase/migrations
# or run each file:
psql "$DATABASE_URL" -f supabase/migrations/0001_schema.sql
psql "$DATABASE_URL" -f supabase/migrations/0002_functions_triggers.sql
psql "$DATABASE_URL" -f supabase/migrations/0003_rls.sql
psql "$DATABASE_URL" -f supabase/migrations/0004_seed.sql
```

### 3. Configure the app
```bash
cp .env.example .env
# edit .env with your values:
#   SUPABASE_URL=https://xxxx.supabase.co
#   SUPABASE_ANON_KEY=eyJhbGciOi...
```

### 4. Run
```bash
flutter pub get
flutter run -d chrome      # Web
flutter run -d <android>   # Android device/emulator
```
> The first time you create the Flutter platform folders (if missing) run:
> `flutter create . --platforms=android,web --org io.reparto`
> (the provided `android/` and `web/` configs already match `io.reparto.app`).

---

## 🔐 Auth notes

### Create the first admin
Admins are **not** self-registered. Create one by signing up normally, then in
the SQL editor:
```sql
update public.users set role = 'admin' where email = 'you@university.edu';
```

### Email verification
Supabase enforces email confirmation by default (matches the spec's "Email
verification is mandatory"). For local testing you may toggle it off under
**Authentication → Providers → Email**.

### Google Sign-In
1. Enable Google provider in **Authentication → Providers**.
2. Add the redirect URL `io.reparto.app://login-callback/` (mobile) and your web
   origin.
3. The Android deep link is already declared in
   `android/app/src/main/AndroidManifest.xml`.
4. First-time Google users are routed to **Select Campus** automatically.

---

## 🛡 Security & business rules (enforced in DB)

- **Campus isolation** — students only see vendors/products from their own
  campus; enforced by RLS using `current_campus()`.
- **Approved vendors only** — `place_order_from_cart()` and product write
  policies require `approval_status = 'approved'`.
- **Reviews after completion** — `validate_review()` trigger blocks reviews
  unless a `completed` order exists for that student↔vendor pair.
- **Auto unavailability** — `sync_product_availability()` flips products to
  `unavailable` at zero stock.
- **Atomic checkout** — orders, items, stock decrement, cart clear, and vendor
  notification all happen inside one `place_order_from_cart()` transaction.
- **Notifications** — triggers fire on new order, status change, and vendor
  approval/suspension.

---

## 📦 Order lifecycle

`pending → accepted → preparing → ready_for_pickup → completed`
(any active order may be `cancelled`). Vendors advance status from their Orders
tab; students can cancel while `pending`.

---

## 🧭 Next steps / extension ideas
- Firebase Cloud Messaging for push notifications (table + trigger already emit
  in-app notifications; add an Edge Function to forward to FCM).
- Image upload to Supabase Storage (replace the image-URL text field).
- Vendor analytics charts, payments integration, chat.
- iOS target (`flutter create . --platforms=ios`).

---

© UjustBUY.
