import { getGoogleAccessToken, parseServiceAccountJson } from "../_shared/googleAccessToken.ts";
import { createRecaptchaAssessment } from "../_shared/recaptchaAssessment.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const RECAPTCHA_SCOPE = "https://www.googleapis.com/auth/cloud-platform";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const rawJson =
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ??
      Deno.env.get("RECAPTCHA_SERVICE_ACCOUNT_JSON");
    const sa = parseServiceAccountJson(rawJson ?? undefined);
    const siteKey = Deno.env.get("RECAPTCHA_ENTERPRISE_SITE_KEY")?.trim();

    const body = await req.json().catch(() => ({})) as {
      token?: string;
      action?: string;
    };

    if (!sa || !siteKey) {
      return new Response(
        JSON.stringify({
          ok: true,
          skipped: true,
          message: "Server reCAPTCHA assessment not configured (service account or site key missing)",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const token = body.token?.trim();
    const action = body.action?.trim() || "phone_otp_request";

    if (!token) {
      return new Response(JSON.stringify({ ok: false, error: "Missing recaptcha token" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const minScore = Number(Deno.env.get("RECAPTCHA_MIN_SCORE") ?? "0.35");
    const accessToken = await getGoogleAccessToken(sa, [RECAPTCHA_SCOPE]);
    const result = await createRecaptchaAssessment(
      accessToken,
      sa.project_id,
      siteKey,
      token,
      action,
    );

    if (!result.ok) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: result.error,
          invalidReason: "invalidReason" in result ? result.invalidReason : undefined,
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (result.score < minScore) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: "Risk score too low",
          score: result.score,
          minScore,
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        ok: true,
        score: result.score,
        reasons: result.reasons,
        action: result.action,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("[recaptcha-assessment]", e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
