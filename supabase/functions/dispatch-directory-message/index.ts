import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

function normalizeWhatsAppPhone(raw: string | null | undefined): string | null {
  if (!raw?.trim()) return null;
  let digits = raw.replace(/\D/g, "");
  if (digits.length === 10) digits = `91${digits}`;
  if (digits.length < 11 || digits.length > 15) return null;
  return digits;
}

function normalizeEmail(raw: string | null | undefined): string | null {
  const v = raw?.trim().toLowerCase() ?? "";
  if (!v) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) return null;
  return v;
}

async function sendWhatsAppMessage(
  phoneNumberId: string,
  token: string,
  to: string,
  title: string,
  message: string,
  imageUrl?: string | null,
): Promise<{ ok: boolean; error?: string }> {
  const caption = `${title}\n\n${message}`.slice(0, 1024);
  const body: Record<string, unknown> = {
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to,
  };
  if (imageUrl) {
    body.type = "image";
    body.image = { link: imageUrl, caption };
  } else {
    body.type = "text";
    body.text = { body: caption };
  }
  const res = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const errText = await res.text();
    return { ok: false, error: errText.slice(0, 300) };
  }
  return { ok: true };
}

async function sendResendEmail(
  resendKey: string,
  from: string,
  to: string,
  title: string,
  message: string,
): Promise<{ ok: boolean; error?: string }> {
  const html = `<p style="font-family:sans-serif;white-space:pre-wrap">${message
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")}</p>`;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: title.slice(0, 200),
      html,
      text: message,
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
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const body = await req.json();
    const society_id = body.society_id as string | undefined;
    const title = String(body.title ?? "").trim();
    const message = String(body.message ?? "").trim();
    const channels = body.channels ?? {};
    const wantWa = !!channels.whatsapp;
    const wantEmail = !!channels.email;
    const target_type = (body.target_type as string) || "all";
    const target_flat_numbers: string[] = Array.isArray(body.target_flat_numbers)
      ? body.target_flat_numbers.map(String)
      : [];
    const target_ids: string[] = Array.isArray(body.target_ids) ? body.target_ids.map(String) : [];
    const image_url = typeof body.image_url === "string" ? body.image_url : null;

    if (!society_id || !title || !message) {
      return new Response(JSON.stringify({ error: "society_id, title, and message are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!wantWa && !wantEmail) {
      return new Response(JSON.stringify({ skipped: "no_channels", whatsapp_sent: 0, email_sent: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let flatsQuery = supabase.from("flats").select("id, flat_number, owner_phone").eq("society_id", society_id);
    if (target_type === "flat" && target_flat_numbers.length > 0) {
      flatsQuery = flatsQuery.in("flat_number", target_flat_numbers);
    }
    const { data: flats } = await flatsQuery;
    let flatRows = flats ?? [];

    if (target_type === "user" && target_ids.length > 0) {
      const { data: users } = await supabase
        .from("resident_users")
        .select("id, flat_id, phone, email, whatsapp_phone")
        .in("id", target_ids);
      const flatIds = [...new Set((users ?? []).map((u) => u.flat_id).filter(Boolean))];
      flatRows = flatRows.filter((f) => flatIds.includes(f.id));
    }

    const flatIds = flatRows.map((f) => f.id);
    const flatById = new Map(flatRows.map((f) => [f.id, f]));

    const phones = new Set<string>();
    const emails = new Set<string>();

    if (flatIds.length > 0) {
      const { data: members } = await supabase
        .from("members")
        .select(
          "flat_id, name, phone, whatsapp_phone, email, notify_whatsapp, notify_email, is_primary",
        )
        .in("flat_id", flatIds)
        .order("is_primary", { ascending: false });

      for (const m of members ?? []) {
        if (wantWa && m.notify_whatsapp !== false) {
          const p = normalizeWhatsAppPhone(m.whatsapp_phone ?? m.phone);
          if (p) phones.add(p);
        }
        if (wantEmail && m.notify_email !== false) {
          const e = normalizeEmail(m.email);
          if (e) emails.add(e);
        }
      }

      const { data: residents } = await supabase
        .from("resident_users")
        .select("flat_id, phone, email, whatsapp_phone")
        .in("flat_id", flatIds);

      for (const r of residents ?? []) {
        if (wantWa) {
          const p = normalizeWhatsAppPhone(r.whatsapp_phone ?? r.phone);
          if (p) phones.add(p);
        }
        if (wantEmail) {
          const e = normalizeEmail(r.email);
          if (e) emails.add(e);
        }
      }
    }

    if (wantWa) {
      for (const f of flatRows) {
        const p = normalizeWhatsAppPhone(f.owner_phone);
        if (p) phones.add(p);
      }
    }

    if (target_type === "user" && target_ids.length > 0) {
      const { data: users } = await supabase
        .from("resident_users")
        .select("phone, email, whatsapp_phone")
        .in("id", target_ids);
      phones.clear();
      emails.clear();
      for (const r of users ?? []) {
        if (wantWa) {
          const p = normalizeWhatsAppPhone(r.whatsapp_phone ?? r.phone);
          if (p) phones.add(p);
        }
        if (wantEmail) {
          const e = normalizeEmail(r.email);
          if (e) emails.add(e);
        }
      }
    }

    void flatById;

    const waToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
    const waPhoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
    let whatsapp_sent = 0;
    let whatsapp_failed = 0;
    if (wantWa && waToken && waPhoneId) {
      for (const phone of phones) {
        const result = await sendWhatsAppMessage(waPhoneId, waToken, phone, title, message, image_url);
        if (result.ok) whatsapp_sent++;
        else whatsapp_failed++;
        await new Promise((r) => setTimeout(r, 100));
      }
    }

    const resendKey = Deno.env.get("RESEND_API_KEY")?.trim();
    const from = Deno.env.get("RESEND_FROM")?.trim() || "onboarding@resend.dev";
    let email_sent = 0;
    let email_failed = 0;
    if (wantEmail && resendKey) {
      for (const to of emails) {
        const result = await sendResendEmail(resendKey, from, to, title, message);
        if (result.ok) email_sent++;
        else email_failed++;
        await new Promise((r) => setTimeout(r, 80));
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        whatsapp_recipients: phones.size,
        whatsapp_sent,
        whatsapp_failed,
        whatsapp_configured: Boolean(waToken && waPhoneId),
        email_recipients: emails.size,
        email_sent,
        email_failed,
        email_configured: Boolean(resendKey),
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
