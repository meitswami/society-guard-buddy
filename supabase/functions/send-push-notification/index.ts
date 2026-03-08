import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

const ONESIGNAL_APP_ID = '56605d90-2aff-4fb3-b97d-e423ad959d0b';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY');
    if (!ONESIGNAL_REST_API_KEY) {
      return new Response(JSON.stringify({ error: 'OneSignal API key not configured' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { title, message, target_type, target_ids, target_flat_numbers } = await req.json();

    if (!title || !message) {
      return new Response(JSON.stringify({ error: 'Title and message required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Build OneSignal payload based on target
    const payload: any = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
    };

    if (target_type === 'all') {
      // Send to all subscribed users
      payload.included_segments = ['Subscribed Users'];
    } else if (target_type === 'flat' && target_flat_numbers?.length > 0) {
      // Target specific flats by tag
      payload.filters = target_flat_numbers.flatMap((flat: string, i: number) => {
        const filter: any[] = [];
        if (i > 0) filter.push({ operator: 'OR' });
        filter.push({ field: 'tag', key: 'flat_number', value: flat });
        return filter;
      });
    } else if (target_type === 'user' && target_ids?.length > 0) {
      // Target specific users by external user id
      payload.include_aliases = { external_id: target_ids };
      payload.target_channel = 'push';
    } else {
      payload.included_segments = ['Subscribed Users'];
    }

    const res = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(payload),
    });

    const result = await res.json();

    return new Response(JSON.stringify({ success: true, onesignal_response: result }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
