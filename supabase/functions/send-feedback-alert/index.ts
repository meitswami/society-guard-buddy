import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const DEFAULT_TO = 'meit10swami@gmail.com'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = (await req.json()) as { ticket_id?: string }
    const ticketId = body.ticket_id?.trim()
    if (!ticketId) {
      return new Response(JSON.stringify({ error: 'ticket_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: row, error: fetchErr } = await supabase
      .from('support_tickets')
      .select('*')
      .eq('id', ticketId)
      .maybeSingle()

    if (fetchErr || !row) {
      return new Response(JSON.stringify({ error: 'Ticket not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const to = (Deno.env.get('FEEDBACK_ALERT_EMAIL')?.trim() || DEFAULT_TO).toLowerCase()
    const resendKey = Deno.env.get('RESEND_API_KEY')?.trim()
    const from = Deno.env.get('RESEND_FROM')?.trim() || 'onboarding@resend.dev'

    const num = row.ticket_number as number
    const society = (row.society_name as string) || '—'
    const member = (row.submitter_name as string) || '—'
    const flat = (row.flat_number as string) || '—'
    const created = row.created_at as string
    const msg = String(row.message ?? '').slice(0, 8000)
    const media = Array.isArray(row.media_items) ? row.media_items : []
    const audio = (row.audio_url as string) || ''

    const html = `
      <h2>New app feedback · Ticket #${num}</h2>
      <p><strong>Society:</strong> ${escapeHtml(society)}</p>
      <p><strong>Member:</strong> ${escapeHtml(member)}</p>
      <p><strong>Flat:</strong> ${escapeHtml(flat)}</p>
      <p><strong>Resident user id:</strong> ${escapeHtml(String(row.submitter_resident_id ?? ''))}</p>
      <p><strong>Submitted:</strong> ${escapeHtml(created)}</p>
      <p><strong>Message:</strong></p>
      <pre style="white-space:pre-wrap;font-family:sans-serif">${escapeHtml(msg)}</pre>
      ${audio ? `<p><strong>Voice note:</strong> <a href="${escapeAttr(audio)}">Open audio</a></p>` : ''}
      ${media.length ? `<p><strong>Attachments:</strong></p><ul>${(media as { url?: string; kind?: string }[])
        .map((m) => `<li><a href="${escapeAttr(String(m.url ?? ''))}">${escapeHtml(String(m.kind ?? 'file'))}</a></li>`)
        .join('')}</ul>` : ''}
    `

    if (!resendKey) {
      console.warn(`[send-feedback-alert] No RESEND_API_KEY; ticket #${num} email skipped`)
      return new Response(JSON.stringify({ ok: true, skipped: true, reason: 'no_resend' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject: `[Kutumbika] New feedback #${num} · ${society} · Flat ${flat} · ${member}`,
        html,
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

    return new Response(JSON.stringify({ ok: true }), {
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

function escapeHtml(s: string) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function escapeAttr(s: string) {
  return s.replace(/"/g, '%22').replace(/'/g, '%27')
}
