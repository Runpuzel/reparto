# Push Notifications & Device Tokens — Setup & Troubleshooting

## Why the device token was not being generated

The `device_tokens` table stays empty when **any** of these are true. They must
ALL be satisfied for a token to be created and saved:

1. **`ENABLE_PUSH` was `false`** in `.env`.
   The whole push pipeline (`Firebase.initializeApp()` → `PushService.init()` →
   `getToken()` → write to `device_tokens`) is gated behind this flag. With it
   off, the app never even asks Firebase for a token. **Fix:** set
   `ENABLE_PUSH=true`.

2. **No Firebase config file.**
   `android/app/google-services.json` (Android) and
   `ios/Runner/GoogleService-Info.plist` (iOS) were missing, so
   `Firebase.initializeApp()` cannot connect to a Firebase project and
   `getToken()` returns null / throws.

3. **The Google Services Gradle plugin was disabled.**
   Now auto-applied in `android/app/build.gradle` *only when*
   `google-services.json` exists.

4. **The `device_tokens` migration wasn't applied**, or **RLS blocked the
   insert** (the policy requires `user_id = auth.uid()`, so the user must be
   signed in — which the app already ensures).

The code now logs each step and never registers when Firebase isn't ready, so
you'll see clear messages in `flutter run` / `adb logcat`.

---

## Step-by-step fix

### 1. Create a Firebase project & app
- Go to the [Firebase console](https://console.firebase.google.com/), create a
  project (or reuse one).
- Add an **Android app** with package name **`io.reparto.app`** (matches
  `applicationId` in `android/app/build.gradle`).
- Download **`google-services.json`** and place it at
  **`android/app/google-services.json`**.
- (iOS) Add an iOS app, download **`GoogleService-Info.plist`** into
  `ios/Runner/` via Xcode.

> The recommended path is the FlutterFire CLI:
> ```
> dart pub global activate flutterfire_cli
> flutterfire configure
> ```
> It writes `lib/firebase_options.dart` and the native config files for you. If
> you use it, change `Firebase.initializeApp()` in `lib/main.dart` to
> `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

### 2. Apply the database migration
Run `supabase/migrations/0006_feature_upgrades.sql` (creates `device_tokens`
with RLS). If you use the Supabase CLI: `supabase db push`.

### 3. Turn the flag on
In `.env`:
```
ENABLE_PUSH=true
```

### 4. Rebuild (not hot reload)
Native plugin + Gradle changes require a full rebuild:
```
flutter clean
flutter pub get
flutter run
```

### 5. Verify in-app
Sign in, open **Profile → Push notifications → "Register / test device"**.
It will request permission, fetch the FCM token, and upsert it into
`device_tokens`. The result text tells you exactly what happened.

Then check Supabase: **Table editor → `device_tokens`** should show a row with
your `user_id`, the `token`, and the `platform`.

---

## Web push (optional)
Web needs a **VAPID key** (Firebase console → Project settings → Cloud
Messaging → Web push certificates). Provide it at build time and set it before
init, e.g. in `main.dart` after Firebase init:
```dart
PushService.webVapidKey = const String.fromEnvironment('FCM_VAPID_KEY');
```
You also need `firebase-messaging-sw.js` in `web/`.

---

## Sending a push
Tokens are consumed by the `send-push` Edge Function
(`supabase/functions/send-push`). Make sure it's deployed and its secrets
(`FCM_*`) are set. With tokens now present in `device_tokens`, order/status
events that call the function will deliver notifications.

## Quick checklist
- [ ] `google-services.json` in `android/app/`
- [ ] `ENABLE_PUSH=true` in `.env`
- [ ] `0006_feature_upgrades.sql` migration applied
- [ ] Full `flutter clean && flutter run` (not hot reload)
- [ ] Granted the notification permission prompt
- [ ] Row appears in `device_tokens` (use the in-app test button)
