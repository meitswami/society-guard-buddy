// AI receptionist kiosk: turn a short Hindi / Hinglish / English speech transcript
// into one structured visitor detail. The kiosk only calls this when its own
// rule-based parsing is unsure, so requests are tiny and infrequent.
//
// Secret: ANTHROPIC_API_KEY  (supabase secrets set ANTHROPIC_API_KEY=...)
import Anthropic from 'npm:@anthropic-ai/sdk@0.126.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type Field = 'name' | 'phone' | 'flat' | 'purpose' | 'vehicle' | 'yesno' | 'editField'

const FIELD_RULES: Record<Field, string> = {
  name:
    "The visitor was asked for their full name. Return only the person's name in Roman (English) letters, " +
    "Title Case, without words like 'mera naam', 'hai', 'ji', 'my name is'. Transliterate Devanagari " +
    'names the way Indians usually spell them (राहुल शर्मा → Rahul Sharma).',
  phone:
    'The visitor was asked for their 10-digit Indian mobile number. Return only the 10 digits (no +91, ' +
    'no spaces). Convert spoken digit words in Hindi or English ("नौ", "nau", "double five") to digits.',
  flat:
    'The visitor was asked which flat they are visiting. Return the flat exactly as written in the ' +
    'society flat list when one matches (Hindi number words like "छह सौ चार" mean 604; "ए" / "a wing" ' +
    'means wing A). If no list is given, return wing letter and number like "A-604" or just "604".',
  purpose:
    'The visitor was asked why they came. Return exactly one of: Visit, Delivery, Meeting, Maintenance, ' +
    'Guest, Other. Food / parcel / courier / Amazon / Swiggy etc. = Delivery; plumber, electrician, ' +
    'repair, cleaning = Maintenance; relatives or friends = Guest; meeting a resident = Visit.',
  vehicle:
    'The visitor was asked for their vehicle registration number. Return it in capitals without ' +
    'spaces, e.g. MH02AB1234. Letters spoken as names in Devanagari (एम एच = MH) become letters.',
  yesno:
    'The visitor was asked a yes / no confirmation question. Return "yes" or "no".',
  editField:
    'The visitor was shown their details and asked what to change. Return exactly one of: name, phone, ' +
    'flat, purpose, vehicle — or "none" if they said everything is correct.',
}

const SYSTEM =
  'You read speech-recognition transcripts from a housing-society gate kiosk in India. Visitors speak ' +
  'Hindi, Hinglish or English; transcripts can contain recognition mistakes. Extract only the requested ' +
  'detail. If the transcript does not contain it, set found to false and value to an empty string. ' +
  'Never invent details.'

const OUTPUT_SCHEMA = {
  type: 'object',
  properties: {
    found: { type: 'boolean' },
    value: { type: 'string' },
  },
  required: ['found', 'value'],
  additionalProperties: false,
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
const client = apiKey ? new Anthropic({ apiKey, timeout: 8_000, maxRetries: 1 }) : null

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405)
  if (!client) return json({ error: 'ANTHROPIC_API_KEY not configured' }, 503)

  let body: { field?: string; transcripts?: unknown; lang?: string; flats?: unknown }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'invalid JSON' }, 400)
  }

  const field = body.field as Field
  if (!field || !(field in FIELD_RULES)) return json({ error: 'unknown field' }, 400)
  const transcripts = Array.isArray(body.transcripts)
    ? body.transcripts.filter((t): t is string => typeof t === 'string' && t.trim() !== '').slice(0, 3).map((t) => t.slice(0, 300))
    : []
  if (!transcripts.length) return json({ found: false, value: '' })
  const flats = field === 'flat' && Array.isArray(body.flats)
    ? body.flats.filter((f): f is string => typeof f === 'string').slice(0, 800).map((f) => f.slice(0, 20))
    : []
  const lang = ['hi', 'hinglish', 'en'].includes(String(body.lang)) ? String(body.lang) : 'hi'

  const prompt = [
    `Detail wanted: ${field}`,
    FIELD_RULES[field],
    `Kiosk language: ${lang}`,
    flats.length ? `Society flat list: ${flats.join(', ')}` : '',
    'Recogniser transcripts (best first):',
    ...transcripts.map((t, i) => `${i + 1}. ${t}`),
  ].filter(Boolean).join('\n')

  try {
    const response = await client.beta.messages.create({
      model: 'claude-opus-5-5',
      max_tokens: 1024,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      system: SYSTEM,
      output_config: {
        effort: 'low',
        format: { type: 'json_schema', schema: OUTPUT_SCHEMA },
      },
      messages: [{ role: 'user', content: prompt }],
    } as Parameters<typeof client.beta.messages.create>[0])

    if (response.stop_reason === 'refusal') return json({ found: false, value: '' })
    const text = response.content.find((b) => b.type === 'text')
    if (!text || text.type !== 'text') return json({ found: false, value: '' })
    let parsed: { found?: unknown; value?: unknown }
    try {
      parsed = JSON.parse(text.text)
    } catch {
      return json({ found: false, value: '' })
    }
    return json({
      found: parsed.found === true,
      value: typeof parsed.value === 'string' ? parsed.value.trim().slice(0, 80) : '',
    })
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return json({ error: 'rate limited' }, 429)
    if (e instanceof Anthropic.APIError) return json({ error: `upstream ${e.status ?? ''}`.trim() }, 502)
    console.error('kiosk-assistant failed', e)
    return json({ error: 'failed' }, 500)
  }
})
