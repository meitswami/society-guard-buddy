import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { phone, countryCode = '+91' } = await req.json()
    if (!phone) {
      return new Response(JSON.stringify({ error: 'Phone number required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
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
