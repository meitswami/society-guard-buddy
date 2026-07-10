import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

function normalizeReferralCode(s: string): string {
  return s.trim().toUpperCase()
}

function makeReferralCode(name: string, societyId: string): string {
  const letters = name
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9 ]+/g, '')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p.slice(0, 4))
    .join('')
    .slice(0, 6)
  const suffix = societyId.replaceAll('-', '').slice(0, 6).toUpperCase()
  return `${letters || 'SOC'}-${suffix}`
}

const FULL_ADMIN_PERMS =
  '{"residents_rw":true,"guards_rw":true,"geofence_rw":true,"finance":true,"fixed_assets":true,"donations":true,"splits":true,"events":true,"meetings":true,"documents":true,"committee":true,"polls":true,"notifications":true,"parking":true,"visitor":true,"delivery":true,"vehicle":true,"blacklist":true,"directory":true,"quick":true,"report":true,"logs":true,"audit":true,"settings":true,"password":true,"biometric":true}'

const SEEDED_ROLES: { role_name: string; slug: string; permissions: string }[] = [
  { role_name: 'Admin', slug: 'admin', permissions: FULL_ADMIN_PERMS },
  {
    role_name: 'Treasurer',
    slug: 'treasurer',
    permissions:
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":true,"fixed_assets":true,"donations":true,"splits":true,"events":true,"meetings":false,"documents":false,"committee":false,"polls":false,"notifications":true,"parking":false,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":true,"logs":false,"audit":false,"settings":false,"password":true,"biometric":true}',
  },
  {
    role_name: 'President',
    slug: 'president',
    permissions:
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":false,"fixed_assets":false,"donations":false,"splits":false,"events":true,"meetings":true,"documents":true,"committee":true,"polls":true,"notifications":true,"parking":true,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":true,"logs":true,"audit":true,"settings":false,"password":true,"biometric":true}',
  },
  {
    role_name: 'Vice-President',
    slug: 'vice_president',
    permissions:
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":false,"fixed_assets":false,"donations":false,"splits":false,"events":true,"meetings":true,"documents":true,"committee":true,"polls":true,"notifications":true,"parking":true,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":true,"logs":true,"audit":false,"settings":false,"password":true,"biometric":true}',
  },
  {
    role_name: 'Secretary',
    slug: 'secretary',
    permissions:
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":false,"fixed_assets":false,"donations":false,"splits":false,"events":true,"meetings":true,"documents":true,"committee":true,"polls":true,"notifications":true,"parking":false,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":false,"logs":false,"audit":false,"settings":false,"password":true,"biometric":true}',
  },
]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const expectedUser = Deno.env.get('PHONEPE_WEBHOOK_USERNAME')?.trim() || ''
    const expectedPass = Deno.env.get('PHONEPE_WEBHOOK_PASSWORD')?.trim() || ''
    if (!expectedUser || !expectedPass) throw new Error('Webhook auth not configured')

    const auth = req.headers.get('Authorization') || ''
    const expected = await sha256Hex(`${expectedUser}:${expectedPass}`)
    if (auth.toLowerCase() !== expected.toLowerCase()) {
      return new Response(JSON.stringify({ ok: false }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const payload = body?.payload ?? {}
    const merchantOrderId = String(payload?.merchantOrderId || '').trim()
    const state = String(payload?.state || '').toUpperCase()
    if (!merchantOrderId) throw new Error('Missing merchantOrderId')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: order, error: oErr } = await supabase
      .from('society_orders')
      .select('id, signup_id, status')
      .eq('merchant_transaction_id', merchantOrderId)
      .maybeSingle()
    if (oErr || !order) throw new Error('Order not found')

    const nextStatus =
      state === 'COMPLETED' ? 'success' : state === 'FAILED' ? 'failed' : state === 'CANCELLED' ? 'cancelled' : null

    if (nextStatus) {
      await supabase
        .from('society_orders')
        .update({
          status: nextStatus,
          callback_payload: body,
          callback_verified: true,
        })
        .eq('id', order.id)
    }

    if (nextStatus !== 'success') {
      await supabase.from('society_signups').update({ status: nextStatus === 'failed' ? 'failed' : 'cancelled' }).eq('id', order.signup_id)
      return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Provision idempotency: if already provisioned, stop.
    const { data: signup } = await supabase
      .from('society_signups')
      .select('*')
      .eq('id', order.signup_id)
      .single()

    if (signup?.status === 'provisioned') {
      return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Create society from signup snapshot
    const { data: createdSociety, error: sErr } = await supabase
      .from('societies')
      .insert({
        name: signup.society_name,
        address: signup.address,
        city: signup.city,
        state: signup.state,
        pincode: signup.pincode,
        block_names: signup.block_names,
        total_floors: signup.total_floors,
        flats_per_floor: signup.flats_per_floor,
        flat_series_start: signup.flat_series_start,
        flat_series_end: signup.flat_series_end,
        is_active: true,
      })
      .select('id, name')
      .single()
    if (sErr) throw sErr

    const referral_code = makeReferralCode(createdSociety.name, createdSociety.id)
    await supabase.from('societies').update({ referral_code }).eq('id', createdSociety.id)

    // Seed roles for this society
    for (const r of SEEDED_ROLES) {
      await supabase.from('society_roles').insert({
        society_id: createdSociety.id,
        role_name: r.role_name,
        slug: r.slug,
        permissions: JSON.parse(r.permissions),
      })
    }

    const { data: adminRole } = await supabase
      .from('society_roles')
      .select('id')
      .eq('society_id', createdSociety.id)
      .eq('slug', 'admin')
      .maybeSingle()

    // Create initial admin with submitted credentials
    await supabase.from('admins').insert({
      name: signup.contact_person || 'Administrator',
      admin_id: signup.admin_id,
      password: signup.admin_password,
      society_id: createdSociety.id,
      role_id: adminRole?.id ?? null,
      email: signup.contact_email,
    })

    // Referral rewards (10% + 10%) as society wallet credits
    const referralUsed = String(signup.referral_code_used || '').trim()
    if (referralUsed) {
      const code = normalizeReferralCode(referralUsed)
      const { data: refSociety } = await supabase
        .from('societies')
        .select('id')
        .ilike('referral_code', code)
        .maybeSingle()
      if (refSociety?.id) {
        const credit = Math.round(8500 * 0.1)
        // Idempotent record per order
        const { data: refRow } = await supabase
          .from('society_referrals')
          .select('id')
          .eq('order_id', order.id)
          .maybeSingle()
        if (!refRow?.id) {
          await supabase.from('society_referrals').insert({
            order_id: order.id,
            referrer_society_id: refSociety.id,
            referred_society_id: createdSociety.id,
            referral_code_used: code,
            reward_percent: 10,
            referrer_reward_inr: credit,
            referred_reward_inr: credit,
          })
          await supabase.from('society_wallet_ledger').insert([
            { society_id: refSociety.id, entry_type: 'credit', amount_inr: credit, source_order_id: order.id, notes: 'Referral reward (10%)' },
            { society_id: createdSociety.id, entry_type: 'credit', amount_inr: credit, source_order_id: order.id, notes: 'Welcome offer (10%)' },
          ])
        }
      }
    }

    await supabase.from('society_signups').update({ status: 'provisioned' }).eq('id', order.signup_id)

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('phonepe-callback', e)
    return new Response(JSON.stringify({ ok: false }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

