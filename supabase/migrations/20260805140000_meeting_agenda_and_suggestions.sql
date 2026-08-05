-- Meeting notice: agenda items (admin + resident-proposed) and free-form suggestions.

CREATE TABLE public.meeting_agenda_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  title text NOT NULL,
  details text,
  sort_order integer NOT NULL DEFAULT 0,
  source text NOT NULL DEFAULT 'admin',
  status text NOT NULL DEFAULT 'accepted',
  proposed_by_member_id uuid REFERENCES public.members(id) ON DELETE SET NULL,
  proposed_by_name text,
  proposed_by_flat text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT meeting_agenda_items_source_check CHECK (source = ANY (ARRAY['admin'::text, 'resident'::text])),
  CONSTRAINT meeting_agenda_items_status_check CHECK (
    status = ANY (ARRAY['proposed'::text, 'accepted'::text, 'rejected'::text, 'deferred'::text])
  )
);

CREATE TABLE public.meeting_suggestions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  member_id uuid REFERENCES public.members(id) ON DELETE SET NULL,
  author_name text NOT NULL,
  flat_number text,
  suggestion_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_meeting_agenda_items_meeting_id ON public.meeting_agenda_items (meeting_id, sort_order);
CREATE INDEX idx_meeting_suggestions_meeting_id ON public.meeting_suggestions (meeting_id, created_at DESC);

ALTER TABLE public.meeting_agenda_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meeting_agenda_items all" ON public.meeting_agenda_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "meeting_suggestions all" ON public.meeting_suggestions FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.meeting_agenda_items TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.meeting_suggestions TO anon, authenticated, service_role;
