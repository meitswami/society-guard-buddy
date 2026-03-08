import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const body = await req.json().catch(() => ({}));
    const societyId = body.society_id || null;
    const sendEmail = body.send_email || false;
    const emailTo = body.email_to || 'meit10swami@gmail.com';

    // Tables to backup
    const tables = [
      'societies', 'admins', 'society_roles', 'guards', 'guard_shifts',
      'flats', 'members', 'resident_users', 'resident_vehicles',
      'visitors', 'blacklist', 'approval_requests', 'visitor_passes',
      'maintenance_charges', 'maintenance_payments',
      'donation_campaigns', 'donation_payments',
      'events', 'event_rsvps', 'event_contributions',
      'polls', 'poll_options', 'poll_votes',
      'notifications', 'parking_spaces', 'expense_groups', 'expenses', 'expense_splits',
      'geofence_settings', 'biometric_credentials', 'audit_logs',
    ];

    const backup: Record<string, any[]> = {};
    let societyName = 'All Societies';

    // Get society name if filtered
    if (societyId) {
      const { data: soc } = await supabase.from('societies').select('name').eq('id', societyId).single();
      if (soc) societyName = soc.name;
    }

    for (const table of tables) {
      let query = supabase.from(table).select('*');
      // Filter by society_id if the table has it and a filter is provided
      if (societyId && ['admins', 'guards', 'flats', 'maintenance_charges', 'donation_campaigns',
        'events', 'polls', 'notifications', 'parking_spaces', 'expense_groups'].includes(table)) {
        query = query.eq('society_id', societyId);
      }
      const { data, error } = await query;
      if (!error && data) {
        backup[table] = data;
      } else {
        backup[table] = [];
      }
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const safeName = societyName.replace(/[^a-zA-Z0-9]/g, '_');
    const filename = `backup_${safeName}_${timestamp}.json`;

    const backupData = {
      metadata: {
        exported_at: new Date().toISOString(),
        society_name: societyName,
        society_id: societyId,
        total_tables: Object.keys(backup).length,
        total_records: Object.values(backup).reduce((sum, arr) => sum + arr.length, 0),
      },
      data: backup,
    };

    const jsonStr = JSON.stringify(backupData, null, 2);

    // If send_email is true, send via edge function email
    if (sendEmail) {
      // Store backup record in audit_logs
      await supabase.from('audit_logs').insert({
        event_type: 'backup_export',
        user_type: 'system',
        user_name: 'Auto Backup',
        severity: 'info',
        details: {
          society_name: societyName,
          email_to: emailTo,
          total_records: backupData.metadata.total_records,
          filename,
        },
      });

      // We'll use OneSignal to notify about backup (email sending is limited)
      // For now, return the backup data and log the attempt
      return new Response(JSON.stringify({
        success: true,
        message: `Backup created for ${societyName}`,
        filename,
        metadata: backupData.metadata,
        backup_json: jsonStr,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Return downloadable backup
    return new Response(jsonStr, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="${filename}"`,
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
