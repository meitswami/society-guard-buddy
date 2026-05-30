-- Emergency / society-wide alert: optional saved WhatsApp numbers + audit log

ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS whatsapp_phone text;

ALTER TABLE public.resident_users
  ADD COLUMN IF NOT EXISTS whatsapp_phone text;

COMMENT ON COLUMN public.members.whatsapp_phone IS 'Saved WhatsApp number for emergency alerts; falls back to phone when null.';
COMMENT ON COLUMN public.resident_users.whatsapp_phone IS 'Saved WhatsApp number for emergency alerts; falls back to phone when null.';

-- Allow guard replies on alert threads
ALTER TABLE public.notification_comments DROP CONSTRAINT IF EXISTS notification_comments_author_role_check;
ALTER TABLE public.notification_comments
  ADD CONSTRAINT notification_comments_author_role_check
  CHECK (author_role IN ('resident', 'admin', 'guard'));

CREATE TABLE IF NOT EXISTS public.emergency_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  notification_id uuid REFERENCES public.notifications(id) ON DELETE SET NULL,
  title text NOT NULL,
  message text NOT NULL,
  sender_role text NOT NULL CHECK (sender_role IN ('guard', 'resident', 'admin')),
  sender_name text NOT NULL,
  sender_flat_number text,
  media_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  push_sent integer NOT NULL DEFAULT 0,
  whatsapp_sent integer NOT NULL DEFAULT 0,
  whatsapp_failed integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS emergency_alerts_society_id_idx ON public.emergency_alerts (society_id);
CREATE INDEX IF NOT EXISTS emergency_alerts_created_at_idx ON public.emergency_alerts (created_at DESC);

ALTER TABLE public.emergency_alerts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "All access emergency_alerts" ON public.emergency_alerts;
CREATE POLICY "All access emergency_alerts"
  ON public.emergency_alerts FOR ALL USING (true) WITH CHECK (true);
