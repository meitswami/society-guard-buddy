import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function normalizeEmail(e: string) {
  return e.trim().toLowerCase()
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = (await req.json()) as { username?: string; recovery_email?: string }
    const username = body.username?.trim().toUpperCase()
    const recoveryEmail = body.recovery_email ? normalizeEmail(body.recovery_email) : ''
    if (!username || !recoveryEmail) {
      return new Response(JSON.stringify({ error: 'Username and recovery email required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: admin, error: fetchErr } = await supabase
      .from('super_admins')
      .select('id, recovery_email')
      .eq('username', username)
      .maybeSingle()

    if (fetchErr || !admin?.recovery_email) {
      return new Response(JSON.stringify({ ok: true, message: 'If the account exists, a code was sent.' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (normalizeEmail(admin.recovery_email) !== recoveryEmail) {
      return new Response(JSON.stringify({ ok: true, message: 'If the account exists, a code was sent.' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const code = String(Math.floor(100000 + Math.random() * 900000))
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString()

    await supabase.from('superadmin_recovery_challenges').delete().eq('super_admin_id', admin.id)

    const { error: insErr } = await supabase.from('superadmin_recovery_challenges').insert({
      super_admin_id: admin.id,
      code,
      expires_at: expiresAt,
    })

    if (insErr) {
      console.error(insErr)
      return new Response(JSON.stringify({ error: 'Could not create recovery code' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const resendKey = Deno.env.get('RESEND_API_KEY')?.trim()
    const from = Deno.env.get('RESEND_FROM')?.trim() || 'onboarding@resend.dev'

    if (resendKey) {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [recoveryEmail],
          subject: 'Super Admin recovery code',
          html: `<p>Your recovery code is:</p><p style="font-size:24px;font-weight:bold;letter-spacing:4px">${code}</p><p>It expires in 15 minutes. If you did not request this, ignore this email.</p>`,
        }),
      })
      if (!res.ok) {
        const t = await res.text()
        console.error('Resend error', res.status, t)
        return new Response(JSON.stringify({ error: 'Could not send email' }), {
          status: 502,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    } else {
      console.warn(`Superadmin recovery code for ${username} (no RESEND_API_KEY): ${code}`)
      const allowDev = Deno.env.get('ALLOW_SUPERADMIN_RECOVERY_DEV_CODE') === 'true'
      if (allowDev) {
        return new Response(
          JSON.stringify({
            ok: true,
            message: 'Email not configured; dev code returned.',
            dev_code: code,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
      }
      return new Response(
        JSON.stringify({
          ok: false,
          error:
            'Email delivery is not configured (set RESEND_API_KEY on the Edge Function, or ALLOW_SUPERADMIN_RECOVERY_DEV_CODE=true for local dev only).',
        }),
        { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    return new Response(JSON.stringify({ ok: true, message: 'If the account exists, a code was sent.' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error(e)
    return new Response(JSON.stringify({ error: 'Server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
