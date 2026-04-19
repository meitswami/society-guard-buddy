-- In-app feedback / support tickets (superadmin triage, resident-targeted replies)
CREATE TABLE public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number integer GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  society_id uuid REFERENCES public.societies (id) ON DELETE SET NULL,
  society_name text,
  submitter_kind text NOT NULL DEFAULT 'resident',
  submitter_resident_id text NOT NULL,
  submitter_name text NOT NULL,
  flat_number text NOT NULL,
  message text NOT NULL DEFAULT '',
  media_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  audio_url text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'resolved', 'future_update')),
  superadmin_reply text,
  replied_by_superadmin_id uuid REFERENCES public.super_admins (id) ON DELETE SET NULL,
  replied_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.support_tickets IS 'Resident feedback; superadmin replies trigger targeted notification + push.';
COMMENT ON COLUMN public.support_tickets.ticket_number IS 'Monotonic ticket # shown as #1, #2, …';
COMMENT ON COLUMN public.support_tickets.media_items IS 'JSON array of {url, kind: image|video}';

CREATE INDEX support_tickets_created_at_idx ON public.support_tickets (created_at DESC);
CREATE INDEX support_tickets_society_id_idx ON public.support_tickets (society_id);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "support_tickets all" ON public.support_tickets
  FOR ALL
  USING (true)
  WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
