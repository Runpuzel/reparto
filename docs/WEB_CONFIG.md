# Web configuration via `env.txt` (no --dart-define)

## The root cause of the `/assets/.env` 404

Netlify (and most static hosts) **do not serve files that begin with a dot**
(`.env`, `.htaccess`, etc.) for security reasons. Even though Flutter bundles
`.env` into `build/web/assets/`, Netlify refuses to serve `/assets/.env` → 404 →
the app can't read its config → it crashes on startup.

## The fix: use `env.txt` (no leading dot)

The config file is now **`env.txt`** at the project root. It's a normal file, so
Netlify serves `/assets/env.txt` fine.

- `pubspec.yaml` bundles `env.txt` as an asset.
- `main.dart` loads `env.txt` first, then falls back to `.env` (local dev), then
  to `--dart-define`.
- `env.txt` is committed (not git-ignored) so Netlify's build includes it.

> ⚠️ `env.txt` is publicly downloadable on the web. Keep ONLY public values in
> it: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (anon key is safe for clients; RLS
> protects data), `GOOGLE_WEB_CLIENT_ID`, `ENABLE_PUSH`, `ENABLE_PAYMENTS`.
> NEVER put service_role key, Paystack secret key, or FCM server key here.

## What you must do

1. Put your **real values** in `env.txt` (replace the `YOUR-PROJECT` /
   `YOUR-ANON-KEY` placeholders):
   ```
   SUPABASE_URL=https://abcd1234.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOi...your anon key...
   GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
   ENABLE_PUSH=false
   ENABLE_PAYMENTS=false
   ```
2. Commit `env.txt` and push.
3. Deploy (Netlify rebuild, or `flutter build web --release` then upload
   `build/web`).

## Verify after deploy
- `https://YOURSITE.netlify.app/assets/env.txt` → shows your config (200, not 404).
- `https://YOURSITE.netlify.app/main.dart.js` → big JavaScript file.
- App loads past the splash screen.

## Note about the Cloudflare console error
`GET /cdn-cgi/challenge-platform/scripts/jsd/main.js → 404` is **not your app**.
It's a Cloudflare bot script injected by a browser extension / VPN / network on
the client side. Netlify has no `/cdn-cgi/` path. It's harmless; test in an
incognito window or another network and it disappears.
