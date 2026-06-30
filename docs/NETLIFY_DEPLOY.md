# Deploying UjustBUY (Flutter web) to Netlify

## The "Uncaught SyntaxError: Unexpected token '<'" error

This means a JavaScript file (`main.dart.js` or `flutter_bootstrap.js`) was
**missing** from the deployed site. Netlify's SPA redirect then returned
`index.html` (HTML) in its place, and the browser tried to parse HTML as
JavaScript → `Unexpected token '<'`.

Almost always the cause is one of:
1. The **build failed or produced an incomplete `build/web`** (wrong build
   command / wrong directory).
2. The **publish directory is `web/`** (the raw template) instead of
   **`build/web`** (the compiled output).

Both are fixed by the `netlify.toml` in this repo.

---

## Recommended: let Netlify build it

1. Push this repo to GitHub/GitLab.
2. Netlify → **Add new site → Import an existing project**.
3. It reads `netlify.toml` automatically:
    - **Build command** clones the Flutter SDK and runs
      `flutter build web --release`.
    - **Publish directory** = `build/web`.
4. Deploy.

> In the Netlify UI, leave the build command and publish directory **blank** so
> the values from `netlify.toml` are used. If the UI has old values, clear them
> or set publish to `build/web`.

---

## Alternative: build locally, upload the result

If Netlify's build is slow or you prefer control:

```bash
flutter build web --release
```

Then deploy the **`build/web`** folder only:

```bash
# Netlify CLI
netlify deploy --prod --dir=build/web
```

or drag‑and‑drop the **`build/web`** folder into the Netlify dashboard.

> ❌ Never deploy `web/`. ✅ Always deploy `build/web`.

---

## How to verify the deploy is correct

After deploying, open these URLs directly in the browser:

- `https://YOURSITE.netlify.app/flutter_bootstrap.js` → should show **JavaScript**
  (not HTML). If you see `<!DOCTYPE html>`, the build output is missing.
- `https://YOURSITE.netlify.app/main.dart.js` → should be a large JS file.
- `https://YOURSITE.netlify.app/manifest.json` → should be JSON.

If any of those return the HTML page, the publish directory is wrong or the
build didn't complete.

---

## If the old icon / old page is cached
Hard refresh: **Ctrl/Cmd + Shift + R**, or open the site in a private window.
`index.html` is served with `Cache-Control: no-cache` so new deploys show up,
but browsers still cache aggressively for PWAs.