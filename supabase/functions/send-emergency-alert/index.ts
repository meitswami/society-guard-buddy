import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

type MediaItem = { url: string; kind: "image" | "video" };

function normalizeWhatsAppPhone(raw: string | null | undefined): string | null {
  if (!raw?.trim()) return null;
  let digits = raw.replace(/\D/g, "");
  if (digits.length === 10) digits = `91${digits}`;
  if (digits.length < 11 || digits.length > 15) return null;
  return digits;
}

async function sendWhatsAppMessage(
  phoneNumberId: string,
  token: string,
  to: string,
  title: string,
  message: string,
  imageUrl?: string,
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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const {
      society_id,
      title,
      message,
      sender_role,
      sender_name,
      sender_flat_number,
      media_items,
    } = await req.json();

    if (!society_id || !title?.trim() || !message?.trim()) {
      return new Response(JSON.stringify({ error: "society_id, title, and message are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const role = typeof sender_role === "string" ? sender_role : "resident";
    if (!["guard", "resident", "admin"].includes(role)) {
      return new Response(JSON.stringify({ error: "Invalid sender_role" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const media: MediaItem[] = Array.isArray(media_items)
      ? media_items.filter((m: MediaItem) => m?.url && (m.kind === "image" || m.kind === "video"))
      : [];

    const createdBy = `${sender_name} (${role}${sender_flat_number ? ` · Flat ${sender_flat_number}` : ""})`;

    const { data: notifRow, error: notifErr } = await supabase
      .from("notifications")
      .insert([
        {
          society_id,
          title: title.trim(),
          message: message.trim(),
          type: "alert",
          target_type: "all",
          target_id: null,
          created_by: createdBy,
          media_items: media,
          sound_key: "siren",
          sound_custom_url: null,
        },
      ])
      .select("id")
      .single();

    if (notifErr) {
      return new Response(JSON.stringify({ error: notifErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let pushSent = 0;
    let pushNote = "";
    try {
      const pushRes = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          title: title.trim(),
          message: message.trim(),
          target_type: "all",
          target_flat_numbers: [],
          target_ids: [],
          media_items: media,
          society_id,
          sound_key: "siren",
          sound_custom_url: "",
        }),
      });
      const pushJson = await pushRes.json();
      pushSent = Number(pushJson?.sent ?? 0);
      pushNote = pushJson?.note ?? "";
    } catch (e) {
      pushNote = String(e);
    }

    const flatIdsRes = await supabase.from("flats").select("id, owner_phone").eq("society_id", society_id);
    const flatIds = (flatIdsRes.data ?? []).map((f: { id: string }) => f.id);

    const phones = new Set<string>();

    for (const f of flatIdsRes.data ?? []) {
      const p = normalizeWhatsAppPhone((f as { owner_phone?: string }).owner_phone);
      if (p) phones.add(p);
    }

    if (flatIds.length > 0) {
      const [membersRes, residentsRes] = await Promise.all([
        supabase
          .from("members")
          .select("phone, whatsapp_phone")
          .in("flat_id", flatIds),
        supabase
          .from("resident_users")
          .select("phone, whatsapp_phone")
          .in("flat_id", flatIds),
      ]);

      for (const row of membersRes.data ?? []) {
        const p = normalizeWhatsAppPhone(row.whatsapp_phone ?? row.phone);
        if (p) phones.add(p);
      }
      for (const row of residentsRes.data ?? []) {
        const p = normalizeWhatsAppPhone(row.whatsapp_phone ?? row.phone);
        if (p) phones.add(p);
      }
    }

    const waToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
    const waPhoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
    let whatsappSent = 0;
    let whatsappFailed = 0;
    const whatsappErrors: string[] = [];
    const firstImage = media.find((m) => m.kind === "image")?.url;

    if (waToken && waPhoneId && phones.size > 0) {
      for (const phone of phones) {
        const result = await sendWhatsAppMessage(
          waPhoneId,
          waToken,
          phone,
          title.trim(),
          message.trim(),
          firstImage,
        );
        if (result.ok) whatsappSent++;
        else {
          whatsappFailed++;
          if (whatsappErrors.length < 3) whatsappErrors.push(result.error ?? "unknown");
        }
        await new Promise((r) => setTimeout(r, 120));
      }
    }

    await supabase.from("emergency_alerts").insert([
      {
        society_id,
        notification_id: notifRow?.id ?? null,
        title: title.trim(),
        message: message.trim(),
        sender_role: role,
        sender_name: sender_name?.trim() || "Unknown",
        sender_flat_number: sender_flat_number?.trim() || null,
        media_items: media,
        push_sent: pushSent,
        whatsapp_sent: whatsappSent,
        whatsapp_failed: whatsappFailed,
      },
    ]);

    return new Response(
      JSON.stringify({
        success: true,
        notification_id: notifRow?.id,
        push_sent: pushSent,
        push_note: pushNote,
        whatsapp_recipients: phones.size,
        whatsapp_sent: whatsappSent,
        whatsapp_failed: whatsappFailed,
        whatsapp_configured: Boolean(waToken && waPhoneId),
        whatsapp_errors: whatsappErrors,
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
