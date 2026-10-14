-- Ring the resident's phone when a guard asks to let a visitor in.
--
-- Until now an approval request (guard visitor entry, AI kiosk) only reached residents whose
-- app was open (realtime). This trigger sends an FCM push for every new pending request,
-- whichever client created it (web, Android app, kiosk), through the existing
-- `send-push-notification` Edge Function (`kind = visitor_approval`: high priority, the
-- "Visitor at gate" channel and doorbell sound on Android).
--
-- The Edge Functions base URL lives in `app_runtime_config` so a move to a self-hosted
-- Supabase only needs one UPDATE (see docs/deploy/SUPABASE-SELF-HOST.md).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.app_runtime_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Server-side settings only: no client (anon) policy, so the API cannot read or change them.
ALTER TABLE public.app_runtime_config ENABLE ROW LEVEL SECURITY;

INSERT INTO public.app_runtime_config (key, value)
VALUES ('functions_base_url', 'https://cyydprpucjeiscetrdfa.supabase.co/functions/v1')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.notify_visitor_approval_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  base_url text;
  soc_id uuid;
  visitor text;
  purpose_text text;
BEGIN
  IF NEW.status IS DISTINCT FROM 'pending' THEN
    RETURN NEW;
  END IF;

  SELECT value INTO base_url FROM public.app_runtime_config WHERE key = 'functions_base_url';
  IF base_url IS NULL OR base_url = '' THEN
    RETURN NEW;
  END IF;

  SELECT society_id INTO soc_id FROM public.flats WHERE id = NEW.flat_id;
  IF soc_id IS NULL THEN
    RETURN NEW;
  END IF;

  visitor := COALESCE(NULLIF(trim(NEW.visitor_name), ''), 'A visitor');
  purpose_text := NULLIF(trim(COALESCE(NEW.purpose, '')), '');

  -- Fire-and-forget: pg_net sends after commit; a push failure never blocks the gate entry.
  PERFORM net.http_post(
    url := base_url || '/send-push-notification',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object(
      'title', 'Visitor at the gate · गेट पर आगंतुक',
      'message', visitor || ' wants to visit flat ' || NEW.flat_number
        || COALESCE(' (' || purpose_text || ')', '')
        || '. Open the app to approve or reject.',
      'target_type', 'flat',
      'target_flat_numbers', jsonb_build_array(NEW.flat_number),
      'society_id', soc_id,
      'kind', 'visitor_approval',
      'data', jsonb_build_object('request_id', NEW.id, 'flat_number', NEW.flat_number)
    ),
    timeout_milliseconds := 10000
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never fail the guard's insert because of the push.
  RAISE WARNING 'visitor approval push failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS approval_requests_push ON public.approval_requests;
CREATE TRIGGER approval_requests_push
  AFTER INSERT ON public.approval_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_visitor_approval_push();
