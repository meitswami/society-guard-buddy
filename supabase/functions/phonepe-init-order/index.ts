import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type SignupInput = {
  society_name: string
  address?: string
  city?: string
  state?: string
  pincode?: string
  blocks_csv?: string
  total_floors?: string
  flats_per_floor?: string
  flat_series_start?: string
  flat_series_end?: string
  contact_person?: string
  contact_phone?: string
  contact_email?: string
  referral_code?: string
  admin_id?: string
  admin_password?: string
}

let cachedToken: { token: string; expires_at: number } | null = null

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function getPhonePeAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && cachedToken.expires_at - 30 > now) return cachedToken.token

  const clientId = Deno.env.get('PHONEPE_CLIENT_ID')?.trim()
  const clientSecret = Deno.env.get('PHONEPE_CLIENT_SECRET')?.trim()
  const clientVersion = Deno.env.get('PHONEPE_CLIENT_VERSION')?.trim() || '1'
  const env = (Deno.env.get('PHONEPE_ENV') || 'SANDBOX').toUpperCase()
  if (!clientId || !clientSecret) throw new Error('PhonePe OAuth not configured')

  const url =
    env === 'PROD'
      ? 'https://api.phonepe.com/apis/identity-manager/v1/oauth/token'
      : 'https://api-preprod.phonepe.com/apis/pg-sandbox/v1/oauth/token'

  const form = new URLSearchParams()
  form.set('client_id', clientId)
  form.set('client_secret', clientSecret)
  form.set('client_version', clientVersion)
  form.set('grant_type', 'client_credentials')

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form.toString(),
  })
  const json = await res.json()
  if (!res.ok) throw new Error(json?.message || 'PhonePe token failed')

  cachedToken = { token: json.access_token, expires_at: Number(json.expires_at || 0) }
  return cachedToken.token
}

function randToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24))
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')
}

function parseIntOrNull(v: string | undefined): number | null {
  const t = (v ?? '').trim()
  if (!t) return null
  const n = parseInt(t, 10)
  return Number.isFinite(n) ? n : null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = (await req.json()) as SignupInput
    if (!body.society_name?.trim()) {
      return new Response(JSON.stringify({ error: 'Society name required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (!body.contact_phone?.trim()) {
      return new Response(JSON.stringify({ error: 'Contact phone required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (!body.admin_id?.trim() || !body.admin_password?.trim()) {
      return new Response(JSON.stringify({ error: 'Admin ID and password required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // If society already exists, treat it as already paid/listed and do not initiate payment.
    const wantedName = body.society_name.trim()
    const { data: existingSociety } = await supabase
      .from('societies')
      .select('id, name, is_active')
      .ilike('name', wantedName)
      .maybeSingle()
    if (existingSociety?.id) {
      return new Response(
        JSON.stringify({
          alreadyExists: true,
          societyId: existingSociety.id,
          societyName: existingSociety.name,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const blocks = (body.blocks_csv ?? '')
      .split(/[,;]+/)
      .map((x) => x.trim())
      .filter(Boolean)
    const block_names = blocks.length ? blocks : null

    const base_price_inr = 8500
    const client_token = randToken()

    // Validate referral code (optional) – resolved later for rewards
    let referral_code_used: string | null = null
    if (body.referral_code?.trim()) {
      const code = body.referral_code.trim()
      const { data: s } = await supabase
        .from('societies')
        .select('id')
        .ilike('referral_code', code)
        .maybeSingle()
      if (s?.id) referral_code_used = code
    }

    const { data: signup, error: sErr } = await supabase
      .from('society_signups')
      .insert({
        status: 'pending',
        society_name: body.society_name.trim(),
        address: body.address?.trim() || null,
        city: body.city?.trim() || null,
        state: body.state?.trim() || null,
        pincode: body.pincode?.trim() || null,
        block_names,
        total_floors: parseIntOrNull(body.total_floors),
        flats_per_floor: parseIntOrNull(body.flats_per_floor),
        flat_series_start: body.flat_series_start?.trim() || null,
        flat_series_end: body.flat_series_end?.trim() || null,
        contact_person: body.contact_person?.trim() || null,
        contact_phone: body.contact_phone.trim(),
        contact_email: body.contact_email?.trim() || null,
        referral_code_used,
        base_price_inr,
        discount_percent: 0,
        final_price_inr: base_price_inr,
        client_token,
        admin_id: body.admin_id.trim(),
        admin_password: body.admin_password.trim(),
      })
      .select('id')
      .single()
    if (sErr) throw sErr

    const merchantOrderId = `SGS-${signup.id}`.slice(0, 63)
    const amountPaisa = base_price_inr * 100

    const frontendBase = Deno.env.get('PUBLIC_SITE_URL')?.trim()
    if (!frontendBase) throw new Error('PUBLIC_SITE_URL not configured')

    const env = (Deno.env.get('PHONEPE_ENV') || 'SANDBOX').toUpperCase()
    const payUrl =
      env === 'PROD'
        ? 'https://api.phonepe.com/apis/pg/checkout/v2/pay'
        : 'https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/pay'

    const token = await getPhonePeAccessToken()
    const redirectUrl = `${frontendBase.replace(/\\/$/, '')}/#/society-signup/status?signupId=${signup.id}&token=${client_token}`

    const payload = {
      merchantOrderId,
      amount: amountPaisa,
      expireAfter: 3600,
      paymentFlow: {
        type: 'PG_CHECKOUT',
        message: 'Kutumbika society onboarding',
        merchantUrls: { redirectUrl },
      },
      disablePaymentRetry: false,
      metaInfo: {
        udf1: String(signup.id),
      },
      prefillUserLoginDetails: {
        phoneNumber: body.contact_phone.trim(),
      },
    }

    const res = await fetch(payUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `O-Bearer ${token}`,
      },
      body: JSON.stringify(payload),
    })
    const json = await res.json()
    if (!res.ok) {
      throw new Error(json?.message || 'PhonePe initiate failed')
    }

    const redirect = String(json.redirectUrl || '')
    const { error: oErr } = await supabase.from('society_orders').insert({
      signup_id: signup.id,
      provider: 'phonepe',
      amount_inr: base_price_inr,
      currency: 'INR',
      status: 'created',
      merchant_transaction_id: merchantOrderId,
      redirect_url: redirect || null,
    })
    if (oErr) throw oErr

    return new Response(
      JSON.stringify({
        signupId: signup.id,
        token: client_token,
        amountInr: base_price_inr,
        redirectUrl: redirect,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('phonepe-init-order', e)
    return new Response(JSON.stringify({ error: 'Init failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

