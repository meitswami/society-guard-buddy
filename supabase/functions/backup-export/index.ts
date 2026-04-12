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

    // All public app tables (order stable for diffs)
    const tables = [
      'admins',
      'approval_requests',
      'audit_logs',
      'biometric_credentials',
      'blacklist',
      'donation_campaigns',
      'donation_payments',
      'event_contributions',
      'event_rsvps',
      'events',
      'expense_groups',
      'expense_splits',
      'expenses',
      'fcm_web_tokens',
      'flats',
      'geofence_settings',
      'guard_documents',
      'guard_shifts',
      'guards',
      'maintenance_charges',
      'maintenance_payments',
      'members',
      'notification_comments',
      'notifications',
      'otp_codes',
      'parking_spaces',
      'password_reset_tokens',
      'poll_options',
      'poll_votes',
      'polls',
      'resident_users',
      'resident_vehicles',
      'societies',
      'society_roles',
      'super_admins',
      'superadmin_recovery_challenges',
      'visitor_passes',
      'visitors',
    ];

    const societyScopedTables = [
      'admins',
      'donation_campaigns',
      'events',
      'expense_groups',
      'fcm_web_tokens',
      'flats',
      'guards',
      'maintenance_charges',
      'notifications',
      'parking_spaces',
      'polls',
      'society_roles',
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
      if (societyId && societyScopedTables.includes(table)) {
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
        full_database: !societyId,
        tables_exported: tables,
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
