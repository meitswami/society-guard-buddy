-- Step 2b — point server-side jobs at the self-hosted Edge Functions.
-- Run by import-selfhost.sh with  -v api_url=https://api.kutumbika.meitcybersolutions.com

-- Visitor-approval push trigger (migration 20261014120000) reads this URL.
INSERT INTO public.app_runtime_config (key, value)
VALUES ('functions_base_url', :'api_url' || '/functions/v1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

-- Monthly maintenance bills (cron jobs are not part of the dump; recreate them here).
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
DO $$ BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'issue-monthly-maintenance-1st';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
SELECT cron.schedule(
  'issue-monthly-maintenance-1st',
  '30 3 1 * *',
  format($cron$
  SELECT net.http_post(
    url := %L,
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $cron$, :'api_url' || '/functions/v1/issue-monthly-maintenance')
);

SELECT key, value FROM public.app_runtime_config;
SELECT jobname, schedule FROM cron.job;
