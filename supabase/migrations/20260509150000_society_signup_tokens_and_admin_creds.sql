-- Harden onboarding tables and store bootstrap admin credentials on signup

ALTER TABLE public.society_signups
  ADD COLUMN IF NOT EXISTS client_token text,
  ADD COLUMN IF NOT EXISTS admin_id text,
  ADD COLUMN IF NOT EXISTS admin_password text;

CREATE UNIQUE INDEX IF NOT EXISTS society_signups_client_token_uidx
  ON public.society_signups (client_token)
  WHERE client_token IS NOT NULL AND length(trim(client_token)) > 0;

-- Lock down public selects: status is exposed via an edge function that validates signup_id + client_token
DROP POLICY IF EXISTS "Society signups readable by all (limited use)" ON public.society_signups;
DROP POLICY IF EXISTS "Society orders readable by all (limited use)" ON public.society_orders;

CREATE POLICY IF NOT EXISTS "Society signups no client reads" ON public.society_signups
  FOR SELECT USING (false);
CREATE POLICY IF NOT EXISTS "Society orders no client reads" ON public.society_orders
  FOR SELECT USING (false);

