import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { signupId, token } = await req.json()
    if (!signupId || !token) {
      return new Response(JSON.stringify({ error: 'signupId and token required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: signup } = await supabase
      .from('society_signups')
      .select('id, status, society_name')
      .eq('id', signupId)
      .eq('client_token', token)
      .maybeSingle()

    if (!signup) {
      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: order } = await supabase
      .from('society_orders')
      .select('status, merchant_transaction_id, amount_inr, created_at')
      .eq('signup_id', signupId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    return new Response(
      JSON.stringify({
        signupId: signup.id,
        status: signup.status,
        societyName: signup.society_name,
        order: order ?? null,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('phonepe-poll-status', e)
    return new Response(JSON.stringify({ error: 'Poll failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

