import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

const DEFAULT_BACKUP_EMAIL = "meit10swami@gmail.com";

/** All public app tables we export (stable order). */
const TABLES = [
  "admins",
  "approval_requests",
  "audit_logs",
  "biometric_credentials",
  "blacklist",
  "donation_campaigns",
  "donation_payments",
  "event_contributions",
  "event_rsvps",
  "events",
  "expense_groups",
  "expense_splits",
  "expenses",
  "fcm_web_tokens",
  "flats",
  "geofence_settings",
  "guard_documents",
  "guard_shifts",
  "guards",
  "maintenance_charges",
  "maintenance_payments",
  "members",
  "notification_comments",
  "notifications",
  "otp_codes",
  "parking_spaces",
  "password_reset_tokens",
  "poll_options",
  "poll_votes",
  "polls",
  "resident_users",
  "resident_vehicles",
  "societies",
  "society_roles",
  "super_admins",
  "superadmin_recovery_challenges",
  "support_tickets",
  "visitor_passes",
  "visitors",
] as const;

const SOCIETY_SCOPED_TABLES = new Set<string>([
  "admins",
  "donation_campaigns",
  "events",
  "expense_groups",
  "fcm_web_tokens",
  "flats",
  "guards",
  "maintenance_charges",
  "notifications",
  "parking_spaces",
  "polls",
  "society_roles",
  "support_tickets",
]);

function utf8ToBase64(s: string): string {
  const bytes = new TextEncoder().encode(s);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const body = await req.json().catch(() => ({})) as {
      society_id?: string | null;
      send_email?: boolean;
      email_to?: string;
      complete_db?: boolean;
    };
    const societyId = body.society_id && String(body.society_id).trim() ? String(body.society_id).trim() : null;
    const sendEmail = Boolean(body.send_email);
    const emailTo = (body.email_to || Deno.env.get("BACKUP_EMAIL")?.trim() || DEFAULT_BACKUP_EMAIL).toLowerCase();
    const completeDb = Boolean(body.complete_db);

    const backup: Record<string, unknown[]> = {};
    let societyName = "All Societies";

    if (societyId) {
      const { data: soc } = await supabase.from("societies").select("name").eq("id", societyId).single();
      if (soc?.name) societyName = soc.name as string;
    }

    let approvalFlatIds: string[] | null = null;
    if (societyId) {
      const { data: flatRows } = await supabase.from("flats").select("id").eq("society_id", societyId);
      approvalFlatIds = (flatRows ?? []).map((r: { id: string }) => r.id);
    }

    for (const table of TABLES) {
      let query = supabase.from(table).select("*");

      if (societyId && table === "approval_requests") {
        if (!approvalFlatIds?.length) {
          backup[table] = [];
          continue;
        }
        query = query.in("flat_id", approvalFlatIds);
      } else if (societyId && SOCIETY_SCOPED_TABLES.has(table)) {
        query = query.eq("society_id", societyId);
      }

      const { data, error } = await query;
      if (!error && data) {
        backup[table] = data as unknown[];
      } else {
        backup[table] = [];
      }
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const safeName = societyName.replace(/[^a-zA-Z0-9]/g, "_");
    const prefix = completeDb ? "complete_database" : "backup";
    const filename = `${prefix}_${safeName}_${timestamp}.json`;

    const backupData = {
      metadata: {
        exported_at: new Date().toISOString(),
        society_name: societyName,
        society_id: societyId,
        full_database: !societyId,
        complete_database_export: completeDb && !societyId,
        tables_exported: [...TABLES],
        total_tables: Object.keys(backup).length,
        total_records: Object.values(backup).reduce((sum, arr) => sum + arr.length, 0),
      },
      data: backup,
    };

    const jsonStr = JSON.stringify(backupData, null, 2);
    const byteLength = new TextEncoder().encode(jsonStr).length;

    if (sendEmail) {
      const resendKey = Deno.env.get("RESEND_API_KEY")?.trim();
      const from = Deno.env.get("RESEND_FROM")?.trim() || "onboarding@resend.dev";
      const maxAttach = 12 * 1024 * 1024;

      let emailed = false;
      let emailNote = "";

      if (!resendKey) {
        emailNote = "RESEND_API_KEY is not set on the project; backup JSON was not emailed.";
        console.warn("[backup-export]", emailNote);
      } else if (byteLength > maxAttach) {
        emailNote = `Backup is ${byteLength} bytes (max ${maxAttach} for attachment). Send a manual export from the app.`;
        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from,
            to: [emailTo],
            subject: `Society Guard Buddy backup (too large to attach) — ${societyName}`,
            html: `<p>${escapeHtml(emailNote)}</p><p><strong>Records:</strong> ${backupData.metadata.total_records}</p><p><strong>Filename:</strong> ${escapeHtml(filename)}</p>`,
          }),
        });
        if (!res.ok) {
          console.warn("[backup-export] Resend notify failed", await res.text());
        } else {
          emailed = true;
        }
      } else {
        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from,
            to: [emailTo],
            subject: `Society Guard Buddy backup — ${societyName}`,
            html: `<p>Scheduled or manual backup export.</p><p><strong>Society:</strong> ${escapeHtml(societyName)}</p><p><strong>Records:</strong> ${backupData.metadata.total_records}</p><p>JSON is attached.</p>`,
            attachments: [{ filename, content: utf8ToBase64(jsonStr) }],
          }),
        });
        if (!res.ok) {
          const t = await res.text();
          console.warn("[backup-export] Resend attachment failed", t);
          emailNote = t.slice(0, 500);
        } else {
          emailed = true;
        }
      }

      await supabase.from("audit_logs").insert({
        event_type: "backup_export",
        user_type: "system",
        user_name: "Auto Backup",
        severity: "info",
        details: {
          society_name: societyName,
          email_to: emailTo,
          total_records: backupData.metadata.total_records,
          filename,
          bytes: byteLength,
          emailed,
          email_note: emailNote || null,
        },
      });

      return new Response(
        JSON.stringify({
          ok: true,
          emailed,
          email_note: emailNote || undefined,
          filename,
          metadata: backupData.metadata,
          byte_length: byteLength,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Manual download: always JSON envelope so supabase-js parses reliably.
    return new Response(
      JSON.stringify({
        ok: true,
        filename,
        backup: backupData,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
