import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

const DEFAULT_AMOUNT = 2500;

function getZonedParts(now: Date, timeZone: string) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hour12: false,
    minute: "2-digit",
  });
  const parts = formatter.formatToParts(now);
  const byType = (t: string) => parts.find((p) => p.type === t)?.value || "00";
  return {
    year: Number(byType("year")),
    month: Number(byType("month")),
    day: Number(byType("day")),
    hour: Number(byType("hour")),
    minute: Number(byType("minute")),
  };
}

function normalizeTitle(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}

function isMonthlyMaintenanceCharge(row: { title?: unknown; frequency?: unknown }) {
  return normalizeTitle(row.frequency) === "monthly" && normalizeTitle(row.title).includes("maint");
}

function monthNameUtc(year: number, month: number) {
  return new Date(Date.UTC(year, month - 1, 1)).toLocaleString("en-US", {
    month: "long",
    timeZone: "UTC",
  });
}

function matchesCurrentMonthTitle(title: string, year: number, month: number) {
  const lower = normalizeTitle(title);
  const name = monthNameUtc(year, month).toLowerCase();
  const mm = String(month).padStart(2, "0");
  const yyyy = String(year);
  return (
    lower.includes(name) ||
    lower.includes(`${mm}/${yyyy}`) ||
    lower.includes(`${mm}-${yyyy}`) ||
    lower.includes(`${yyyy}-${mm}`)
  );
}

function buildCurrentMonthChargeTitle(year: number, month: number) {
  return `${monthNameUtc(year, month)} Monthly Maintenance`;
}

function billingMonthKey(year: number, month: number) {
  return `${year}-${String(month).padStart(2, "0")}`;
}

function normalizeWhatsAppPhone(raw: string | null | undefined): string | null {
  if (!raw?.trim()) return null;
  let digits = raw.replace(/\D/g, "");
  if (digits.length === 10) digits = `91${digits}`;
  if (digits.length < 11 || digits.length > 15) return null;
  return digits;
}

async function sendWhatsAppText(
  phoneNumberId: string,
  token: string,
  to: string,
  body: string,
): Promise<{ ok: boolean; error?: string }> {
  const res = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to,
      type: "text",
      text: { body: body.slice(0, 4096) },
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    return { ok: false, error: errText.slice(0, 300) };
  }
  return { ok: true };
}

async function sendWhatsAppAudio(
  phoneNumberId: string,
  token: string,
  to: string,
  audioUrl: string,
): Promise<{ ok: boolean; error?: string }> {
  const res = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to,
      type: "audio",
      audio: { link: audioUrl },
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    return { ok: false, error: errText.slice(0, 300) };
  }
  return { ok: true };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let payload: {
      society_id?: string;
      force?: boolean;
      amount?: number;
    } = {};
    try {
      payload = await req.json();
    } catch {
      payload = {};
    }

    const force = payload.force === true;
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const now = new Date();

    let settingsQuery = supabase
      .from("finance_reminder_settings")
      .select(
        "society_id, enabled, timezone, due_day, auto_issue_enabled, auto_issue_whatsapp, bill_sound_key",
      );
    if (payload.society_id) {
      settingsQuery = settingsQuery.eq("society_id", payload.society_id);
    } else if (!force) {
      settingsQuery = settingsQuery.eq("auto_issue_enabled", true);
    }

    const { data: settingsRows, error: settingsErr } = await settingsQuery;
    if (settingsErr) {
      return new Response(JSON.stringify({ error: settingsErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Societies without settings row: still allow forced single-society run.
    let societies: Array<{
      society_id: string;
      timezone: string;
      due_day: number;
      auto_issue_enabled: boolean;
      auto_issue_whatsapp: boolean;
      bill_sound_key: string;
    }> = (settingsRows ?? []).map((s) => ({
      society_id: String(s.society_id),
      timezone: String(s.timezone || "Asia/Kolkata"),
      due_day: Math.min(28, Math.max(1, Number(s.due_day) || 1)),
      auto_issue_enabled: s.auto_issue_enabled !== false,
      auto_issue_whatsapp: s.auto_issue_whatsapp !== false,
      bill_sound_key: String(s.bill_sound_key || "melody"),
    }));

    if (societies.length === 0 && payload.society_id) {
      societies = [{
        society_id: payload.society_id,
        timezone: "Asia/Kolkata",
        due_day: 1,
        auto_issue_enabled: true,
        auto_issue_whatsapp: true,
        bill_sound_key: "melody",
      }];
    }

    if (societies.length === 0) {
      return new Response(JSON.stringify({ success: true, issued: 0, note: "no_societies" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const waToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
    const waPhoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
    const billAudioUrl = Deno.env.get("MAINTENANCE_BILL_AUDIO_URL")?.trim() || "";

    const results: Array<Record<string, unknown>> = [];
    let issuedSocieties = 0;

    for (const setting of societies) {
      const zoned = getZonedParts(now, setting.timezone);
      if (!force && zoned.day !== 1) {
        results.push({ society_id: setting.society_id, skipped: "not_day_1" });
        continue;
      }
      if (!force && !setting.auto_issue_enabled) {
        results.push({ society_id: setting.society_id, skipped: "auto_issue_disabled" });
        continue;
      }

      const societyId = setting.society_id;
      const monthKey = billingMonthKey(zoned.year, zoned.month);
      const chargeTitle = buildCurrentMonthChargeTitle(zoned.year, zoned.month);
      const dueDay = setting.due_day;

      const { data: existingLog } = await supabase
        .from("finance_monthly_bill_dispatch_log")
        .select("id")
        .eq("society_id", societyId)
        .eq("billing_month", monthKey)
        .maybeSingle();

      if (existingLog && !force) {
        results.push({ society_id: societyId, skipped: "already_issued", billing_month: monthKey });
        continue;
      }

      const { data: monthlyCharges } = await supabase
        .from("maintenance_charges")
        .select("id, title, amount, due_day, frequency, expense_group_id, is_active")
        .eq("society_id", societyId)
        .eq("frequency", "monthly")
        .order("created_at", { ascending: false });

      const maintCharges = (monthlyCharges ?? []).filter(isMonthlyMaintenanceCharge);
      let charge =
        maintCharges.find((c) => matchesCurrentMonthTitle(String(c.title || ""), zoned.year, zoned.month)) ??
        null;

      const template = maintCharges[0];
      const amount = Number(
        payload.amount ??
          charge?.amount ??
          template?.amount ??
          DEFAULT_AMOUNT,
      ) || DEFAULT_AMOUNT;

      if (!charge) {
        const { data: inserted, error: insertErr } = await supabase
          .from("maintenance_charges")
          .insert([{
            title: chargeTitle,
            amount,
            frequency: "monthly",
            due_day: dueDay,
            created_by: "System",
            society_id: societyId,
            is_active: true,
            expense_group_id: template?.expense_group_id ?? null,
          }])
          .select("id, title, amount, due_day")
          .maybeSingle();

        if (insertErr || !inserted) {
          results.push({
            society_id: societyId,
            error: insertErr?.message || "charge_insert_failed",
          });
          continue;
        }
        charge = inserted;
      }

      const { data: flats } = await supabase
        .from("flats")
        .select("id, flat_number, owner_name, owner_phone, is_occupied")
        .eq("society_id", societyId)
        .eq("is_occupied", true);

      const occupied = (flats ?? []).filter((f) => f.flat_number);
      if (occupied.length === 0) {
        results.push({ society_id: societyId, skipped: "no_occupied_flats" });
        continue;
      }

      const flatIds = occupied.map((f) => f.id);
      const flatById = new Map(occupied.map((f) => [f.id, f]));

      const [membersRes, residentsRes] = await Promise.all([
        supabase
          .from("members")
          .select("id, flat_id, name, phone, whatsapp_phone")
          .in("flat_id", flatIds),
        supabase
          .from("resident_users")
          .select("id, flat_id, name, phone, whatsapp_phone, flat_number")
          .in("flat_id", flatIds),
      ]);

      const soundKey = setting.bill_sound_key || "melody";
      const notifTitle = `${chargeTitle} — ₹${amount.toLocaleString("en-IN")}`;
      const notifMessage =
        `Your monthly maintenance bill of ₹${amount.toLocaleString("en-IN")} for ${monthNameUtc(zoned.year, zoned.month)} is due on day ${dueDay}. Please pay at the earliest.`;

      const notifRows = occupied.map((f) => ({
        society_id: societyId,
        title: notifTitle,
        message: `Flat ${f.flat_number}: ${notifMessage}`,
        type: "payment_reminder",
        target_type: "flat",
        target_id: String(f.flat_number),
        created_by: "System",
        sound_key: soundKey,
        sound_custom_url: null,
      }));
      await supabase.from("notifications").insert(notifRows);

      await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({
          title: notifTitle,
          message: notifMessage,
          target_type: "flat",
          target_flat_numbers: occupied.map((f) => String(f.flat_number)),
          target_ids: [],
          media_items: [],
          society_id: societyId,
          sound_key: soundKey,
          sound_custom_url: "",
        }),
      });

      // Build per-member WhatsApp recipients (profile phone), one message each.
      type WaTarget = { phone: string; flatNumber: string; name: string };
      const waTargets: WaTarget[] = [];
      const seenPhones = new Set<string>();

      const addTarget = (phoneRaw: string | null | undefined, flatNumber: string, name: string) => {
        const phone = normalizeWhatsAppPhone(phoneRaw);
        if (!phone || seenPhones.has(phone)) return;
        seenPhones.add(phone);
        waTargets.push({ phone, flatNumber, name: name || "Member" });
      };

      for (const m of membersRes.data ?? []) {
        const flat = flatById.get(m.flat_id);
        if (!flat) continue;
        addTarget(m.whatsapp_phone ?? m.phone, String(flat.flat_number), String(m.name || ""));
      }
      for (const r of residentsRes.data ?? []) {
        const flat = flatById.get(r.flat_id);
        const flatNumber = String(flat?.flat_number || r.flat_number || "");
        if (!flatNumber) continue;
        addTarget(r.whatsapp_phone ?? r.phone, flatNumber, String(r.name || ""));
      }
      // Fallback: flat owner phone when no member/resident phone
      for (const f of occupied) {
        const hasMemberPhone = waTargets.some((t) => t.flatNumber === String(f.flat_number));
        if (!hasMemberPhone) {
          addTarget(f.owner_phone, String(f.flat_number), String(f.owner_name || "Owner"));
        }
      }

      let whatsappSent = 0;
      let whatsappFailed = 0;
      const whatsappErrors: string[] = [];

      if (setting.auto_issue_whatsapp && waToken && waPhoneId) {
        for (const t of waTargets) {
          const body =
            `Namaste ${t.name},\n\n` +
            `*${chargeTitle}*\n` +
            `Flat: ${t.flatNumber}\n` +
            `Amount: ₹${amount.toLocaleString("en-IN")}\n` +
            `Due day: ${dueDay} ${monthNameUtc(zoned.year, zoned.month)} ${zoned.year}\n\n` +
            `Please pay maintenance at the earliest.\n` +
            `— Society Guard Buddy`;

          const textResult = await sendWhatsAppText(waPhoneId, waToken, t.phone, body);
          if (textResult.ok) {
            whatsappSent++;
            if (billAudioUrl) {
              await sendWhatsAppAudio(waPhoneId, waToken, t.phone, billAudioUrl);
            }
          } else {
            whatsappFailed++;
            if (whatsappErrors.length < 5) {
              whatsappErrors.push(`${t.flatNumber}:${textResult.error ?? "unknown"}`);
            }
          }
          await new Promise((r) => setTimeout(r, 120));
        }
      }

      const logPayload = {
        society_id: societyId,
        billing_month: monthKey,
        charge_id: charge.id,
        flats_count: occupied.length,
        notifications_sent: occupied.length,
        whatsapp_sent: whatsappSent,
        whatsapp_failed: whatsappFailed,
        forced: force,
      };

      if (existingLog) {
        await supabase
          .from("finance_monthly_bill_dispatch_log")
          .update(logPayload)
          .eq("id", existingLog.id);
      } else {
        await supabase.from("finance_monthly_bill_dispatch_log").insert([logPayload]);
      }

      issuedSocieties++;
      results.push({
        society_id: societyId,
        billing_month: monthKey,
        charge_id: charge.id,
        charge_title: charge.title ?? chargeTitle,
        amount,
        flats: occupied.length,
        notifications_sent: occupied.length,
        whatsapp_targets: waTargets.length,
        whatsapp_sent: whatsappSent,
        whatsapp_failed: whatsappFailed,
        whatsapp_configured: Boolean(waToken && waPhoneId),
        whatsapp_errors: whatsappErrors,
        sound_key: soundKey,
        audio_attached: Boolean(billAudioUrl),
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        issued: issuedSocieties,
        results,
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
