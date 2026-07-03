import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ─── Shared helpers (inline) ───────────────────────────────────────────────
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

// ─── Webhook logic ──────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const paystackKey = Deno.env.get('PAYSTACK_SECRET_KEY')!;
    const admin = createClient(supabaseUrl, serviceKey);

    const { reference } = await req.json();
    if (typeof reference !== 'string' || !reference.startsWith('wallet-')) {
      return json({ error: 'Invalid reference' }, 400);
    }

    // Verify with Paystack
    const response = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      {
        headers: { Authorization: `Bearer ${paystackKey}` },
      }
    );
    const result = await response.json();

    if (!response.ok || result.data?.status !== 'success') {
      return json({ status: 'pending', message: 'Payment is not complete' });
    }

    // Fetch the expected amount from our database
    const { data: topup } = await admin
      .from('wallet_topups')
      .select('amount_pesewas')
      .eq('reference', reference)
      .single();

    if (!topup || topup.amount_pesewas !== result.data.amount) {
      return json({ error: 'Top‑up amount mismatch' }, 409);
    }

    // Credit the seller's wallet
    const { error } = await admin.rpc('credit_wallet_topup', {
      p_reference: reference,
    });

    if (error) {
      console.error('RPC error:', error);
      return json({ error: error.message }, 500);
    }

    return json({ status: 'paid' });
  } catch (error) {
    console.error('Unexpected error:', error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500
    );
  }
});