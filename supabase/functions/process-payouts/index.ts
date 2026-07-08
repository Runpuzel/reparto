import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ─── Define CORS headers and JSON helper directly ──────────────────────────
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

// ─── Rest of your logic ─────────────────────────────────────────────────────
const networkCode = (network: string) => {
  const value = network.toLowerCase().replace(/[^a-z]/g, '')
  if (value.includes('mtn')) return 'MTN'
  if (value.includes('vodafone') || value.includes('telecel')) return 'VOD'
  if (value.includes('airtel') || value.includes('tigo')) return 'ATL'
  throw new Error(`Unsupported MoMo network: ${network}`)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const auth = req.headers.get('Authorization')
  if (!auth) return json({ error: 'Authentication required' }, 401)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const paystackKey = Deno.env.get('PAYSTACK_SECRET_KEY')!
  const admin = createClient(supabaseUrl, serviceKey)
  const body = await req.json().catch(() => ({}))
  const orderId = typeof body.order_id === 'string' ? body.order_id : null

  let query = admin
    .from('payout_jobs')
    .select('*, order_settlements!inner(order_id), vendors!inner(business_name)')
    .in('status', ['pending', 'failed'])
    .lt('attempt_count', 5)
    .order('created_at')
    .limit(10)
  if (orderId) query = query.eq('order_settlements.order_id', orderId)

  const { data: jobs, error } = await query
  if (error) return json({ error: error.message }, 500)

  const results = []
  for (const job of jobs ?? []) {
    const claimed = await admin
      .from('payout_jobs')
      .update({ status: 'processing', attempt_count: job.attempt_count + 1 })
      .eq('payout_id', job.payout_id)
      .eq('status', job.status)
      .select('payout_id')
      .maybeSingle()
    if (!claimed.data) continue

    try {
      const recipientResponse = await fetch('https://api.paystack.co/transferrecipient', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${paystackKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          type: 'mobile_money',
          name: job.vendors.business_name,
          account_number: job.momo_number,
          bank_code: networkCode(job.momo_network),
          currency: 'GHS',
          description: 'Reparto seller payout',
        }),
      })
      const recipient = await recipientResponse.json()
      if (!recipientResponse.ok || !recipient.status) {
        throw new Error(recipient.message ?? 'Could not create transfer recipient')
      }

      const transferResponse = await fetch('https://api.paystack.co/transfer', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${paystackKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          source: 'balance',
          amount: job.amount_pesewas,
          recipient: recipient.data.recipient_code,
          reference: job.provider_reference,
          reason: `Reparto order ${job.order_settlements.order_id}`,
          currency: 'GHS',
        }),
      })
      const transfer = await transferResponse.json()
      if (!transferResponse.ok || !transfer.status) {
        throw new Error(transfer.message ?? 'Transfer submission failed')
      }

      await admin.from('payout_jobs').update({
        status: 'submitted',
        provider_transfer_code: transfer.data.transfer_code,
        failure_reason: null,
      }).eq('payout_id', job.payout_id)
      results.push({ payout_id: job.payout_id, status: 'submitted' })
    } catch (error) {
      await admin.from('payout_jobs').update({
        status: 'failed',
        failure_reason: error instanceof Error ? error.message : String(error),
      }).eq('payout_id', job.payout_id)
      results.push({ payout_id: job.payout_id, status: 'failed' })
    }
  }

  return json({ processed: results.length, results })
})