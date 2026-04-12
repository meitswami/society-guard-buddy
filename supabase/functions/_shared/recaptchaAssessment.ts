export type AssessmentSuccess = {
  ok: true;
  score: number;
  reasons: string[];
  action: string | null;
};

export type AssessmentFailure = {
  ok: false;
  error: string;
  invalidReason?: string;
};

export type AssessmentResult = AssessmentSuccess | AssessmentFailure;

type AssessmentApiResponse = {
  tokenProperties?: {
    valid?: boolean;
    invalidReason?: string;
    action?: string;
  };
  riskAnalysis?: {
    score?: number;
    reasons?: string[];
  };
};

/**
 * reCAPTCHA Enterprise CreateAssessment (REST).
 * @see https://cloud.google.com/recaptcha-enterprise/docs/create-assessment
 */
export async function createRecaptchaAssessment(
  accessToken: string,
  projectId: string,
  siteKey: string,
  token: string,
  expectedAction?: string,
): Promise<AssessmentResult> {
  const body: Record<string, unknown> = {
    event: {
      token,
      siteKey,
    },
  };
  if (expectedAction) {
    (body.event as Record<string, string>).expectedAction = expectedAction;
  }

  const res = await fetch(
    `https://recaptchaenterprise.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/assessments`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );

  const raw = await res.json() as AssessmentApiResponse & { error?: { message?: string } };
  if (!res.ok) {
    return {
      ok: false,
      error: raw.error?.message ?? `HTTP ${res.status}`,
    };
  }

  const valid = raw.tokenProperties?.valid === true;
  if (!valid) {
    return {
      ok: false,
      error: "Invalid token",
      invalidReason: raw.tokenProperties?.invalidReason,
    };
  }

  const action = raw.tokenProperties?.action ?? null;
  if (expectedAction && action !== expectedAction) {
    return {
      ok: false,
      error: `Action mismatch: expected ${expectedAction}, got ${action ?? "none"}`,
    };
  }

  const score = typeof raw.riskAnalysis?.score === "number" ? raw.riskAnalysis!.score! : 0;
  const reasons = (raw.riskAnalysis?.reasons ?? []).map(String);

  return { ok: true, score, reasons, action };
}
