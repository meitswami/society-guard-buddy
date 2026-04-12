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
    const body = (await req.json()) as { username?: string; code?: string }
    const username = body.username?.trim().toUpperCase()
    const code = body.code?.replace(/\D/g, '') ?? ''
    if (!username || code.length !== 6) {
      return new Response(JSON.stringify({ error: 'Username and 6-digit code required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: admin, error: adminErr } = await supabase
      .from('super_admins')
      .select('id, name, username')
      .eq('username', username)
      .maybeSingle()

    if (adminErr || !admin) {
      return new Response(JSON.stringify({ error: 'Invalid code' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: challenge, error: chErr } = await supabase
      .from('superadmin_recovery_challenges')
      .select('*')
      .eq('super_admin_id', admin.id)
      .eq('code', code)
      .gt('expires_at', new Date().toISOString())
      .maybeSingle()

    if (chErr || !challenge) {
      return new Response(JSON.stringify({ error: 'Invalid or expired code' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    await supabase.from('superadmin_recovery_challenges').delete().eq('id', challenge.id)

    return new Response(
      JSON.stringify({
        ok: true,
        profile: { id: admin.id, name: admin.name, username: admin.username },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error(e)
    return new Response(JSON.stringify({ error: 'Server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
