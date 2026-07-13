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

const hasValidPayoutDetails = (vendor: Record<string, unknown>): boolean => {
  const number = String(vendor.momo_number ?? "").replace(/\D/g, "");
  const network = String(vendor.momo_network ?? "")
    .toLowerCase()
    .replace(/[^a-z]/g, "");
  return number.length === 10 &&
    number.startsWith("0") &&
    ["mtn", "vodafone", "telecel", "airteltigo"].includes(network);
};

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

    const body = await req.json().catch(() => ({}));
    const callbackUrl: string | undefined = body?.callback_url;
    const deliveryAddress: string = String(body?.delivery_address ?? "").trim();
    const contactPhone: string = String(body?.contact_phone ?? "").trim();
    const note: string | null = body?.note ? String(body.note).trim() : null;
    const useTokens: boolean = body?.use_tokens === true;
    if (!deliveryAddress || !contactPhone) {
      return json({ error: "Delivery address and contact phone are required" }, 400);
    }

    // Compute cart total server-side
    const { data: cart } = await userClient
      .from("carts")
      .select("cart_id")
      .eq("student_id", user.id)
      .maybeSingle();
    if (!cart) return json({ error: "Cart is empty" }, 400);

    const { data: items, error: itemsErr } = await userClient
      .from("cart_items")
      .select("quantity, products(price, vendor_id)")
      .eq("cart_id", cart.cart_id);
    if (itemsErr) return json({ error: itemsErr.message }, 400);
    if (!items || items.length === 0) return json({ error: "Cart is empty" }, 400);

    let total = 0;
    const vendorIds = new Set<string>();
    for (const it of items as any[]) {
      const product = Array.isArray(it.products) ? it.products[0] : it.products;
      const price = Number(product?.price ?? 0);
      total += price * Number(it.quantity);
      if (product?.vendor_id) vendorIds.add(String(product.vendor_id));
    }
    if (total <= 0) return json({ error: "Cart total is zero" }, 400);
    if (vendorIds.size === 0) {
      return json({ error: "Seller payment setup could not be verified" }, 400);
    }

    const { data: settings, error: settingsErr } = await admin
      .from("platform_settings")
      .select("verification_required_for_prepayment")
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (settingsErr) return json({ error: settingsErr.message }, 500);

    const { data: vendors, error: vendorsErr } = await admin
      .from("vendors")
      .select(
        "vendor_id, is_verified, verification_status, momo_number, momo_network",
      )
      .in("vendor_id", [...vendorIds]);
    if (vendorsErr) return json({ error: vendorsErr.message }, 500);
    if (!vendors || vendors.length !== vendorIds.size) {
      return json({ error: "Seller payment setup could not be verified" }, 400);
    }

    const verificationRequired =
      settings?.verification_required_for_prepayment !== false;
    const vendorPayouts: Record<string, Record<string, unknown>> = {};
    for (const vendor of vendors as Record<string, unknown>[]) {
      if (!hasValidPayoutDetails(vendor)) {
        return json({
          error:
            "A seller has not added a valid Mobile Money payout number. Use Cash on Delivery.",
          code: "seller_payout_required",
        }, 400);
      }
      if (verificationRequired &&
        (vendor.is_verified !== true || vendor.verification_status !== "approved")) {
        return json({
          error:
            "A seller has not completed identity verification. Use Cash on Delivery.",
          code: "seller_verification_required",
        }, 400);
      }
      vendorPayouts[String(vendor.vendor_id)] = {
        momo_number: String(vendor.momo_number),
        momo_network: String(vendor.momo_network),
        identity_verified: true,
      };
    }

    const reference = `rep_${user.id.slice(0, 8)}_${Date.now()}`;
    let tokenDiscountPesewas = 0;
    if (useTokens) {
      const { data: quote } = await userClient.rpc("checkout_token_quote");
      tokenDiscountPesewas = Number(quote?.discount_pesewas ?? 0);
    }
    const amountKobo = Math.max(0, Math.round(total * 100) - tokenDiscountPesewas);

    // Initialize with Paystack
    const initRes = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${paystackSecret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: user.email,
        amount: amountKobo,
        currency: "GHS",
        reference,
        callback_url: callbackUrl,
        channels: ["mobile_money"],
        metadata: { student_id: user.id },
      }),
    });
    const initData = await initRes.json();
    if (!initData.status) {
      return json({ error: initData.message ?? "Init failed" }, 400);
    }

    // Record a pending payment (service role)
    await admin.from("payments").insert({
      student_id: user.id,
      reference,
      amount: total,
      currency: "GHS",
      status: "pending",
      metadata: {
        cart_id: cart.cart_id,
        delivery_address: deliveryAddress,
        contact_phone: contactPhone,
        note,
        use_tokens: useTokens,
        token_discount_pesewas: tokenDiscountPesewas,
        vendor_payouts: vendorPayouts,
      },
    });

    return json({
      authorization_url: initData.data.authorization_url,
      access_code: initData.data.access_code,
      reference,
      amount: total,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
