// Shared CORS headers for all Reparto Edge Functions.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function serviceAccount(): {
  projectId: string;
  clientEmail: string;
  privateKey: string;
} {
  const bundled = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (bundled) {
    const value = JSON.parse(bundled);
    const projectId = String(value.project_id ?? "");
    const clientEmail = String(value.client_email ?? "");
    const privateKey = String(value.private_key ?? "");
    if (projectId && clientEmail && privateKey) {
      return { projectId, clientEmail, privateKey };
    }
    throw new Error("FCM_SERVICE_ACCOUNT is missing required fields");
  }

  const projectId = Deno.env.get("FCM_PROJECT_ID") ?? "";
  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL") ?? "";
  const privateKey = Deno.env.get("FCM_PRIVATE_KEY") ?? "";
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("FCM service account is not configured");
  }
  return { projectId, clientEmail, privateKey };
}

// --- Google OAuth2 helper (service account -> access token) ----------------
async function getAccessToken(): Promise<string> {
  const { clientEmail, privateKey: privateKeyRaw } = serviceAccount();
  const privateKeyPem = privateKeyRaw.replace(/\\n/g, "\n");

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc(header)}.${enc(claim)}`;

  const pem = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const jwt = `${unsigned}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("Failed to get FCM access token");
  return data.access_token;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const expected = Deno.env.get("PUSH_FUNCTION_SECRET");
    const provided = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    if (!expected) {
      return json({ error: "PUSH_FUNCTION_SECRET is not configured" }, 500);
    }
    if (provided !== expected) {
      return json({ error: "Forbidden" }, 403);
    }

    const { projectId } = serviceAccount();

    const { recipient_id, title, body, notification_id } = await req.json();
    if (!recipient_id) return json({ error: "Missing recipient_id" }, 400);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: tokens } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", recipient_id);

    if (!tokens || tokens.length === 0) {
      return json({ sent: 0, reason: "no tokens" });
    }

    const accessToken = await getAccessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    let sent = 0;
    for (const t of tokens) {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title: title ?? "UjustBUY", body: body ?? "" },
            android: { priority: "HIGH" },
            webpush: {
              notification: {
                icon: "/icons/Icon-192.png",
                badge: "/icons/Icon-192.png",
              },
              fcm_options: { link: "/notifications" },
            },
            data: {
              route: "/notifications",
              notification_id: String(notification_id ?? ""),
            },
          },
        }),
      });
      if (res.ok) {
        sent++;
      } else {
        const err = await res.json().catch(() => ({}));
        const status = err?.error?.status;
        if (status === "NOT_FOUND" || status === "INVALID_ARGUMENT") {
          await admin.from("device_tokens").delete().eq("token", t.token);
        }
      }
    }

    return json({ sent });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
