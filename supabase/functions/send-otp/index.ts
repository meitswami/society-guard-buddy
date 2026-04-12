import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getGoogleAccessToken, parseServiceAccountJson } from '../_shared/googleAccessToken.ts'
import { createRecaptchaAssessment } from '../_shared/recaptchaAssessment.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json() as {
      phone?: string
      countryCode?: string
      recaptcha_token?: string
      recaptcha_action?: string
    }
    const { phone, countryCode = '+91', recaptcha_token, recaptcha_action = 'send_otp' } = body
    if (!phone) {
      return new Response(JSON.stringify({ error: 'Phone number required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const rawSa =
      Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ??
      Deno.env.get('RECAPTCHA_SERVICE_ACCOUNT_JSON')
    const sa = parseServiceAccountJson(rawSa ?? undefined)
    const siteKey = Deno.env.get('RECAPTCHA_ENTERPRISE_SITE_KEY')?.trim()
    const requireRecaptcha = Deno.env.get('REQUIRE_RECAPTCHA_FOR_SEND_OTP') === 'true'

    if (requireRecaptcha || (recaptcha_token && sa && siteKey)) {
      if (!recaptcha_token || !sa || !siteKey) {
        return new Response(JSON.stringify({ error: 'reCAPTCHA token required' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      const minScore = Number(Deno.env.get('RECAPTCHA_MIN_SCORE') ?? '0.35')
      const accessToken = await getGoogleAccessToken(sa, [
        'https://www.googleapis.com/auth/cloud-platform',
      ])
      const assess = await createRecaptchaAssessment(
        accessToken,
        sa.project_id,
        siteKey,
        recaptcha_token,
        recaptcha_action,
      )
      if (!assess.ok) {
        return new Response(JSON.stringify({ error: 'reCAPTCHA assessment failed' }), {
          status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      if (assess.score < minScore) {
        return new Response(JSON.stringify({ error: 'reCAPTCHA score too low' }), {
          status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    const FIREBASE_API_KEY = Deno.env.get('FIREBASE_API_KEY')
    if (!FIREBASE_API_KEY) {
      return new Response(JSON.stringify({ error: 'Firebase not configured' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Generate a 6-digit OTP
    const otp = String(Math.floor(100000 + Math.random() * 900000))
    const fullPhone = `${countryCode}${phone}`

    // Store OTP in database with 5 min expiry
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Delete old OTPs for this phone
    await supabase.from('otp_codes').delete().eq('phone', fullPhone)

    // Insert new OTP
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString()
    await supabase.from('otp_codes').insert({
      phone: fullPhone,
      otp_code: otp,
      expires_at: expiresAt,
    })

    // In production, send SMS via Firebase/Twilio/etc.
    // For now, we log it (in development) and return success
    console.log(`OTP for ${fullPhone}: ${otp}`)

    return new Response(JSON.stringify({ 
      success: true, 
      message: 'OTP sent successfully',
      // Remove this in production - only for development/testing
      dev_otp: otp 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Error sending OTP:', error)
    return new Response(JSON.stringify({ error: 'Failed to send OTP' }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
