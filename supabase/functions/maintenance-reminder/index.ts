import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type ReminderSchedule = 'once_12pm' | 'twice_12pm_7pm';
type ReminderSlot = '12pm' | '7pm';

const normalizeTitle = (value: unknown) => String(value ?? '').trim().toLowerCase();

function getZonedParts(now: Date, timeZone: string) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hour12: false,
    minute: '2-digit',
  });
  const parts = formatter.formatToParts(now);
  const byType = (t: string) => parts.find((p) => p.type === t)?.value || '00';
  return {
    year: Number(byType('year')),
    month: Number(byType('month')),
    day: Number(byType('day')),
    hour: Number(byType('hour')),
    minute: Number(byType('minute')),
  };
}

function monthStartIso(year: number, month: number) {
  return `${year}-${String(month).padStart(2, '0')}-01`;
}

function monthEndIso(year: number, month: number) {
  const end = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return `${year}-${String(month).padStart(2, '0')}-${String(end).padStart(2, '0')}`;
}

function matchesCurrentMonthTitle(title: string, year: number, month: number) {
  const lower = normalizeTitle(title);
  const monthName = new Date(Date.UTC(year, month - 1, 1))
    .toLocaleString('en-US', { month: 'long', timeZone: 'UTC' })
    .toLowerCase();
  const mm = String(month).padStart(2, '0');
  const yyyy = String(year);
  return (
    lower.includes(monthName) ||
    lower.includes(`${mm}/${yyyy}`) ||
    lower.includes(`${mm}-${yyyy}`) ||
    lower.includes(`${yyyy}-${mm}`)
  );
}

function isMonthlyMaintenanceCharge(row: Record<string, unknown>) {
  return normalizeTitle(row.frequency) === 'monthly' && normalizeTitle(row.title).includes('maint');
}

function resolveSlot(hour: number): ReminderSlot | null {
  if (hour === 12) return '12pm';
  if (hour === 19) return '7pm';
  return null;
}

function allowsSlot(schedule: ReminderSchedule, slot: ReminderSlot) {
  if (schedule === 'twice_12pm_7pm') return slot === '12pm' || slot === '7pm';
  return slot === '12pm';
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    let payload: { society_id?: string; force_slot?: ReminderSlot } = {};
    try {
      payload = await req.json();
    } catch {
      payload = {};
    }

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const now = new Date();
    let settingsQuery = supabase
      .from('finance_reminder_settings')
      .select('society_id, enabled, schedule, timezone')
      .eq('enabled', true);
    if (payload?.society_id) {
      settingsQuery = settingsQuery.eq('society_id', payload.society_id);
    }
    const { data: settingsRows, error: settingsErr } = await settingsQuery;

    if (settingsErr) {
      return new Response(JSON.stringify({ error: settingsErr.message }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (!settingsRows || settingsRows.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0, note: 'no_active_settings' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let sentCount = 0;
    let societyRuns = 0;

    for (const setting of settingsRows) {
      const timezone = String(setting.timezone || 'Asia/Kolkata');
      const schedule = (setting.schedule === 'twice_12pm_7pm' ? 'twice_12pm_7pm' : 'once_12pm') as ReminderSchedule;
      const zoned = getZonedParts(now, timezone);
      const slot = payload?.force_slot || resolveSlot(zoned.hour);
      if (!slot) continue;
      if (!payload?.force_slot && !allowsSlot(schedule, slot)) continue;

      const societyId = setting.society_id as string;
      if (!societyId) continue;

      const monthStart = monthStartIso(zoned.year, zoned.month);
      const monthEnd = monthEndIso(zoned.year, zoned.month);
      const localDateIso = `${String(zoned.year).padStart(4, '0')}-${String(zoned.month).padStart(2, '0')}-${String(zoned.day).padStart(2, '0')}`;

      const { data: monthlyCharges } = await supabase
        .from('maintenance_charges')
        .select('id, title, amount, due_day, frequency, created_at')
        .eq('society_id', societyId)
        .eq('frequency', 'monthly')
        .order('created_at', { ascending: false });

      const monthlyMaint = (monthlyCharges ?? []).filter((c) => isMonthlyMaintenanceCharge(c as Record<string, unknown>));
      if (monthlyMaint.length === 0) continue;

      const currentMonthCharge =
        monthlyMaint.find((c) => matchesCurrentMonthTitle(String(c.title || ''), zoned.year, zoned.month)) ??
        monthlyMaint[0];

      const dueDay = Number(currentMonthCharge?.due_day || 1);
      if (zoned.day < dueDay) continue;

      const { data: flats } = await supabase
        .from('flats')
        .select('flat_number, owner_name, is_occupied')
        .eq('society_id', societyId)
        .eq('is_occupied', true);

      const occupiedFlats = (flats ?? []).map((f) => String(f.flat_number)).filter(Boolean);
      if (occupiedFlats.length === 0) continue;

      const { data: paidRows } = await supabase
        .from('maintenance_payments')
        .select('flat_number')
        .eq('charge_id', currentMonthCharge.id)
        .eq('payment_status', 'verified')
        .gte('due_date', monthStart)
        .lte('due_date', monthEnd);

      const paidSet = new Set((paidRows ?? []).map((x) => String(x.flat_number)).filter(Boolean));
      const unpaidFlats = occupiedFlats.filter((n) => !paidSet.has(n));
      if (unpaidFlats.length === 0) continue;

      const { data: loggedRows } = await supabase
        .from('finance_reminder_dispatch_log')
        .select('flat_number')
        .eq('society_id', societyId)
        .eq('charge_id', currentMonthCharge.id)
        .eq('reminder_date', localDateIso)
        .eq('reminder_slot', slot)
        .in('flat_number', unpaidFlats);

      const loggedSet = new Set((loggedRows ?? []).map((x) => String(x.flat_number)).filter(Boolean));
      const toNotify = unpaidFlats.filter((n) => !loggedSet.has(n));
      if (toNotify.length === 0) continue;

      const title = 'Maintenance Due Reminder';
      const message = `Your ${currentMonthCharge.title} payment is due. Due day: ${dueDay}. Please pay at the earliest to avoid pending dues.`;

      const rows = toNotify.map((flatNumber) => ({
        society_id: societyId,
        title,
        message,
        type: 'payment_reminder',
        target_type: 'flat',
        target_id: flatNumber,
        created_by: 'System',
      }));
      await supabase.from('notifications').insert(rows);

      await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({
          title,
          message,
          target_type: 'flat',
          target_flat_numbers: toNotify,
          target_ids: [],
          media_items: [],
          society_id: societyId,
          sound_key: 'digital',
          sound_custom_url: '',
        }),
      });

      const logRows = toNotify.map((flatNumber) => ({
        society_id: societyId,
        charge_id: currentMonthCharge.id,
        flat_number: flatNumber,
        reminder_date: localDateIso,
        reminder_slot: slot,
      }));
      await supabase.from('finance_reminder_dispatch_log').upsert(logRows, {
        onConflict: 'society_id,charge_id,flat_number,reminder_date,reminder_slot',
      });

      sentCount += toNotify.length;
      societyRuns += 1;
    }

    return new Response(JSON.stringify({ success: true, sent: sentCount, societies_processed: societyRuns }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
