import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ─── Inline CORS and JSON helpers ──────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

// ─── Main handler ────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const paystackKey = Deno.env.get('PAYSTACK_SECRET_KEY')!;

    const auth = req.headers.get('Authorization') ?? '';
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: auth } },
    });
    const admin = createClient(supabaseUrl, serviceKey);

    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: 'Unauthorized' }, 401);

    const { amount_pesewas } = await req.json();
    const amount = Number(amount_pesewas);
    if (!Number.isInteger(amount) || amount < 500 || amount > 10000000) {
      return json({ error: 'Top-up must be between GH5 and GH100,000' }, 400);
    }

    const { data: vendor } = await admin
      .from('vendors')
      .select('vendor_id, business_name')
      .eq('user_id', user.id)
      .single();

    if (!vendor) return json({ error: 'Seller account not found' }, 404);

    const reference = `wallet-${crypto.randomUUID().replaceAll('-', '')}`;

    // Initialize Paystack transaction
    const response = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${paystackKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: user.email,
        amount,
        currency: 'GHS',
        reference,
        callback_url: 'https://reparto.app/wallet-topup-complete',
        metadata: {
          purpose: 'cod_commission_wallet',
          vendor_id: vendor.vendor_id,
        },
      }),
    });

    const result = await response.json();
    if (!response.ok || !result.status) {
      return json({ error: result.message ?? 'Top-up initialization failed' }, 400);
    }

    // Record the top‑up request in the database
    const { error } = await admin.from('wallet_topups').insert({
      vendor_id: vendor.vendor_id,
      amount_pesewas: amount,
      reference,
    });

    if (error) {
      console.error('DB insert error:', error);
      return json({ error: error.message }, 500);
    }

    return json({
      reference,
      authorization_url: result.data.authorization_url,
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500
    );
  }
});