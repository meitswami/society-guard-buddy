-- Per-resident inbox clear: hide notifications without deleting shared rows.
CREATE TABLE IF NOT EXISTS public.notification_dismissals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  resident_id uuid NOT NULL REFERENCES public.resident_users(id) ON DELETE CASCADE,
  dismissed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (notification_id, resident_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_dismissals_resident_id
  ON public.notification_dismissals(resident_id);

CREATE INDEX IF NOT EXISTS idx_notification_dismissals_notification_id
  ON public.notification_dismissals(notification_id);

ALTER TABLE public.notification_dismissals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "All access notification_dismissals" ON public.notification_dismissals;
CREATE POLICY "All access notification_dismissals"
  ON public.notification_dismissals FOR ALL USING (true) WITH CHECK (true);
