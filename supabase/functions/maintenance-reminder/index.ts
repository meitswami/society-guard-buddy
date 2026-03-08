import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ONESIGNAL_APP_ID = '56605d90-2aff-4fb3-b97d-e423ad959d0b';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY');
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    if (!ONESIGNAL_REST_API_KEY) {
      return new Response(JSON.stringify({ error: 'OneSignal key not set' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get today's date
    const today = new Date();
    const todayStr = today.toISOString().split('T')[0];

    // Find unpaid maintenance payments due today or overdue
    const { data: unpaid } = await supabase
      .from('maintenance_payments')
      .select('id, flat_number, amount, due_date, resident_name, charge_id')
      .eq('payment_status', 'pending')
      .lte('due_date', todayStr);

    if (!unpaid || unpaid.length === 0) {
      return new Response(JSON.stringify({ message: 'No unpaid dues found', sent: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Group by flat number to send one notification per flat
    const flatMap = new Map<string, { amount: number; resident: string; dues: number }>();
    for (const p of unpaid) {
      const existing = flatMap.get(p.flat_number);
      if (existing) {
        existing.amount += Number(p.amount);
        existing.dues += 1;
      } else {
        flatMap.set(p.flat_number, {
          amount: Number(p.amount),
          resident: p.resident_name || 'Resident',
          dues: 1,
        });
      }
    }

    let sentCount = 0;

    for (const [flatNumber, info] of flatMap) {
      const title = '⚠️ Maintenance Due Reminder';
      const message = `Dear ${info.resident}, you have ${info.dues} unpaid maintenance due(s) totalling ₹${info.amount.toLocaleString()}. Please pay at the earliest.`;

      // Send push via OneSignal targeting flat_number tag
      await fetch('https://api.onesignal.com/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
        body: JSON.stringify({
          app_id: ONESIGNAL_APP_ID,
          headings: { en: title },
          contents: { en: message },
          filters: [{ field: 'tag', key: 'flat_number', value: flatNumber }],
        }),
      });

      // Also save as in-app notification
      await supabase.from('notifications').insert([{
        title,
        message,
        type: 'payment_reminder',
        target_type: 'flat',
        target_id: flatNumber,
        created_by: 'System',
      }]);

      sentCount++;
    }

    return new Response(JSON.stringify({ success: true, sent: sentCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
