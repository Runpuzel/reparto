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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const paystackSecret = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!paystackSecret) return json({ error: "Paystack not configured" }, 500);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const admin = createClient(supabaseUrl, serviceKey);

    const {
      data: { user },
    } = await userClient.auth.getUser();
    if (!user) return json({ error: "Unauthorized" }, 401);

    const { reference } = await req.json();
    if (!reference) return json({ error: "Missing reference" }, 400);

    // Ensure the payment belongs to this user.
    const { data: payment } = await admin
      .from("payments")
      .select("*")
      .eq("reference", reference)
      .maybeSingle();
    if (!payment || payment.student_id !== user.id) {
      return json({ error: "Payment not found" }, 404);
    }

    // Verify with Paystack
    const verifyRes = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      { headers: { Authorization: `Bearer ${paystackSecret}` } },
    );
    const verifyData = await verifyRes.json();

    const success = verifyData.status === true && verifyData.data?.status === "success";

    await admin
      .from("payments")
      .update({
        status: success ? "paid" : "failed",
        channel: verifyData.data?.channel,
        verified_at: new Date().toISOString(),
      })
      .eq("reference", reference);

    if (!success) {
      return json({ status: "failed", message: "Payment not successful" }, 200);
    }

    // Place the order from the cart (idempotent)
    const meta = (payment.metadata ?? {}) as Record<string, unknown>;
    const deliveryAddress = String(meta.delivery_address ?? "").trim();
    const contactPhone = String(meta.contact_phone ?? "").trim();
    const note = meta.note ? String(meta.note) : null;

    let orderIds: unknown;
    let rpcErr: { message: string } | null = null;

    if (deliveryAddress && contactPhone) {
      const res = await userClient.rpc("place_order_checkout_paid", {
        p_reference: reference,
        p_delivery_address: deliveryAddress,
        p_contact_phone: contactPhone,
        p_note: note,
      });
      orderIds = res.data;
      rpcErr = res.error;
    } else {
      const res = await userClient.rpc("place_order_from_cart_paid", {
        p_reference: reference,
      });
      orderIds = res.data;
      rpcErr = res.error;
    }
    if (rpcErr) return json({ status: "paid", order_error: rpcErr.message }, 200);

    return json({ status: "paid", orders: orderIds });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});