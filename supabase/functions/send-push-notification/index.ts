import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.2.3/index.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

const ONESIGNAL_APP_ID = "56605d90-2aff-4fb3-b97d-e423ad959d0b";

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const key = await importPKCS8(sa.private_key, "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await res.json();
  if (!json.access_token) {
    throw new Error(`FCM auth failed: ${JSON.stringify(json)}`);
  }
  return json.access_token as string;
}

async function sendFcmToToken(
  accessToken: string,
  projectId: string,
  deviceToken: string,
  title: string,
  body: string,
  imageUrl?: string,
): Promise<{ ok: boolean; status: number; body: string }> {
  const message: Record<string, unknown> = {
    token: deviceToken,
    notification: { title, body },
  };
  if (imageUrl) {
    message.webpush = {
      notification: { title, body, image: imageUrl },
    };
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    },
  );
  const text = await res.text();
  return { ok: res.ok, status: res.status, body: text };
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
      title,
      message,
      target_type,
      target_ids,
      target_flat_numbers,
      media_items,
      society_id,
    } = await req.json();

    if (!title || !message) {
      return new Response(JSON.stringify({ error: "Title and message required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const fcmJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (fcmJson) {
      let sa: ServiceAccount;
      try {
        sa = JSON.parse(fcmJson) as ServiceAccount;
      } catch {
        return new Response(JSON.stringify({ error: "Invalid FIREBASE_SERVICE_ACCOUNT_JSON" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      let tokenQuery = supabase.from("fcm_web_tokens").select("token");

      if (society_id) {
        tokenQuery = tokenQuery.eq("society_id", society_id);
      }

      if (target_type === "flat" && Array.isArray(target_flat_numbers) && target_flat_numbers.length > 0) {
        tokenQuery = tokenQuery.in("flat_number", target_flat_numbers);
      } else if (target_type === "user" && Array.isArray(target_ids) && target_ids.length > 0) {
        tokenQuery = tokenQuery.eq("user_type", "resident").in("app_user_id", target_ids);
      }

      const { data: tokenRows, error: tErr } = await tokenQuery;
      if (tErr) {
        return new Response(JSON.stringify({ error: tErr.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const tokens = [...new Set((tokenRows ?? []).map((r: { token: string }) => r.token).filter(Boolean))];
      if (tokens.length === 0) {
        return new Response(JSON.stringify({ success: true, channel: "fcm", sent: 0, note: "no_tokens" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const accessToken = await getFcmAccessToken(sa);
      const firstImage = Array.isArray(media_items)
        ? media_items.find((m: { kind?: string; url?: string }) => m?.kind === "image" && m?.url)
        : undefined;
      const firstVideo = Array.isArray(media_items)
        ? media_items.find((m: { kind?: string; url?: string }) => m?.kind === "video" && m?.url)
        : undefined;
      const imageUrl = (firstImage?.url || firstVideo?.url) as string | undefined;

      let sent = 0;
      const errors: string[] = [];
      for (const tok of tokens) {
        const r = await sendFcmToToken(accessToken, sa.project_id, tok, title, message, imageUrl);
        if (r.ok) sent++;
        else if (r.status === 404 || r.body.includes("NOT_FOUND") || r.body.includes("registration-token")) {
          await supabase.from("fcm_web_tokens").delete().eq("token", tok);
        } else {
          errors.push(r.body.slice(0, 200));
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          channel: "fcm",
          sent,
          attempted: tokens.length,
          errors: errors.slice(0, 3),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY");
    if (!ONESIGNAL_REST_API_KEY) {
      return new Response(
        JSON.stringify({
          error: "Configure FIREBASE_SERVICE_ACCOUNT_JSON or ONESIGNAL_REST_API_KEY for push",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const payload: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
    };

    if (Array.isArray(media_items) && media_items.length > 0) {
      const firstImage = media_items.find((m: { kind?: string; url?: string }) => m?.kind === "image" && m?.url);
      const firstVideo = media_items.find((m: { kind?: string; url?: string }) => m?.kind === "video" && m?.url);
      const thumb = firstImage?.url || firstVideo?.url;
      if (thumb) {
        (payload as { big_picture?: string }).big_picture = thumb;
      }
      (payload as { data?: Record<string, string> }).data = {
        media_count: String(media_items.length),
        has_video: media_items.some((m: { kind?: string }) => m?.kind === "video") ? "1" : "0",
      };
    }

    if (target_type === "all") {
      payload.included_segments = ["Subscribed Users"];
    } else if (target_type === "flat" && target_flat_numbers?.length > 0) {
      payload.filters = target_flat_numbers.flatMap((flat: string, i: number) => {
        const filter: unknown[] = [];
        if (i > 0) filter.push({ operator: "OR" });
        filter.push({ field: "tag", key: "flat_number", value: flat });
        return filter;
      });
    } else if (target_type === "user" && target_ids?.length > 0) {
      payload.include_aliases = { external_id: target_ids };
      payload.target_channel = "push";
    } else {
      payload.included_segments = ["Subscribed Users"];
    }

    const res = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(payload),
    });

    const result = await res.json();

    return new Response(JSON.stringify({ success: true, channel: "onesignal", onesignal_response: result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
