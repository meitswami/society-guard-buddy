-- Auto-issue monthly maintenance bills (1st of month) + WhatsApp/push dispatch tracking.

ALTER TABLE public.finance_reminder_settings
  ADD COLUMN IF NOT EXISTS auto_issue_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS auto_issue_whatsapp boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS bill_sound_key text NOT NULL DEFAULT 'melody';

COMMENT ON COLUMN public.finance_reminder_settings.auto_issue_enabled IS
  'When true, issue-monthly-maintenance creates the month charge and notifies members on day 1.';
COMMENT ON COLUMN public.finance_reminder_settings.auto_issue_whatsapp IS
  'When true, also send WhatsApp to each member profile phone (whatsapp_phone → phone).';
COMMENT ON COLUMN public.finance_reminder_settings.bill_sound_key IS
  'In-app / push notification sound preset for monthly bill notices (e.g. melody, chime).';

CREATE TABLE IF NOT EXISTS public.finance_monthly_bill_dispatch_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  billing_month text NOT NULL,
  charge_id uuid REFERENCES public.maintenance_charges(id) ON DELETE SET NULL,
  flats_count integer NOT NULL DEFAULT 0,
  notifications_sent integer NOT NULL DEFAULT 0,
  whatsapp_sent integer NOT NULL DEFAULT 0,
  whatsapp_failed integer NOT NULL DEFAULT 0,
  forced boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, billing_month)
);

ALTER TABLE public.finance_monthly_bill_dispatch_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "All access finance_monthly_bill_dispatch_log" ON public.finance_monthly_bill_dispatch_log;
CREATE POLICY "All access finance_monthly_bill_dispatch_log"
ON public.finance_monthly_bill_dispatch_log
FOR ALL
USING (true)
WITH CHECK (true);

UPDATE public.finance_reminder_settings
SET auto_issue_enabled = true,
    auto_issue_whatsapp = true,
    bill_sound_key = COALESCE(NULLIF(bill_sound_key, ''), 'melody');

-- Cron: 1st of each month at 03:30 UTC (= 09:00 Asia/Kolkata).
DO $$ BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'issue-monthly-maintenance-1st';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'issue-monthly-maintenance-1st',
  '30 3 1 * *',
  $cron$
  SELECT net.http_post(
    url := 'https://cyydprpucjeiscetrdfa.supabase.co/functions/v1/issue-monthly-maintenance',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $cron$
);
