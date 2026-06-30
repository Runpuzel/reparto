# Fixing "localhost refused to connect" on Google Sign-In (web)

## What's happening

On web, "Continue with Google" uses Supabase's OAuth redirect flow:

1. Your app → Google login
2. Google → **Supabase callback** (`https://<project>.supabase.co/auth/v1/callback`)
3. Supabase → **back to your app** at the URL configured as the redirect.

The "localhost refused to connect" error means step 3 is sending users to
`http://localhost` (the dev default) instead of your live Netlify site. This is
a **dashboard configuration** issue — not an app code bug. You must register
your real site URL in THREE places.

---

## 1. Supabase → Authentication → URL Configuration

- **Site URL**: set to your deployed site:
  ```
  https://ujustbuy.netlify.app
  ```
- **Redirect URLs**: add BOTH your site and (optionally) localhost for dev:
  ```
  https://ujustbuy.netlify.app
  https://ujustbuy.netlify.app/
  http://localhost:*
  ```
  (Use your actual Netlify subdomain; if you have several preview URLs, add the
  ones you use.)

## 2. Supabase → Authentication → Providers → Google

- Make sure **Google is enabled**.
- **Client ID** and **Client Secret** come from the Google Cloud OAuth client
  (step 3). Paste them here.
- Note the **Callback URL** shown on this page — it looks like
  `https://<your-project-ref>.supabase.co/auth/v1/callback`. You'll need it next.

## 3. Google Cloud Console → APIs & Services → Credentials → your OAuth 2.0 Web client

- **Authorized JavaScript origins**:
  ```
  https://ujustbuy.netlify.app
  http://localhost
  ```
- **Authorized redirect URIs** — this MUST be the Supabase callback (NOT your
  Netlify URL):
  ```
  https://<your-project-ref>.supabase.co/auth/v1/callback
  ```

> ⚠️ A very common mistake: putting your Netlify URL in "Authorized redirect
> URIs". The redirect URI there must be the **Supabase** callback. Your Netlify
> URL goes in "Authorized JavaScript origins" and in Supabase's "Redirect URLs".

---

## After changing the dashboards

- Google/Supabase changes can take a few minutes to propagate.
- Hard-refresh the site (Ctrl/Cmd+Shift+R) or use a private window.
- Re-test "Continue with Google".

## Quick checklist
- [ ] Supabase Site URL = https://ujustbuy.netlify.app
- [ ] Supabase Redirect URLs include https://ujustbuy.netlify.app
- [ ] Google "Authorized JavaScript origins" includes https://ujustbuy.netlify.app
- [ ] Google "Authorized redirect URIs" = the Supabase /auth/v1/callback URL
- [ ] Google Client ID + Secret pasted into Supabase Google provider
