-- Society meetings: attendees, decisions, discussion/minutes, documents, per-attendee signatures.

CREATE TABLE public.meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  meeting_at timestamptz NOT NULL DEFAULT now(),
  location text,
  status text NOT NULL DEFAULT 'draft',
  published boolean NOT NULL DEFAULT false,
  discussion_notes text,
  minutes_summary text,
  audio_recording_url text,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT meetings_status_check CHECK (status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'completed'::text, 'cancelled'::text]))
);

CREATE TABLE public.meeting_attendees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  member_id uuid REFERENCES public.members(id) ON DELETE SET NULL,
  flat_number text,
  display_name text NOT NULL,
  guest_name text,
  attendee_role text NOT NULL DEFAULT 'member',
  is_present boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT meeting_attendees_role_check CHECK (attendee_role = ANY (ARRAY['member'::text, 'admin'::text, 'guest'::text]))
);

CREATE UNIQUE INDEX meeting_attendees_member_unique
  ON public.meeting_attendees (meeting_id, member_id)
  WHERE member_id IS NOT NULL;

CREATE TABLE public.meeting_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  decision_text text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.meeting_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  title text NOT NULL,
  file_url text NOT NULL,
  file_name text,
  mime_type text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.meeting_document_signatures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_document_id uuid NOT NULL REFERENCES public.meeting_documents(id) ON DELETE CASCADE,
  meeting_attendee_id uuid NOT NULL REFERENCES public.meeting_attendees(id) ON DELETE CASCADE,
  signature_image_url text NOT NULL,
  signed_at timestamptz NOT NULL DEFAULT now(),
  signer_label text,
  CONSTRAINT meeting_document_signatures_unique UNIQUE (meeting_document_id, meeting_attendee_id)
);

CREATE INDEX idx_meetings_society_id ON public.meetings (society_id);
CREATE INDEX idx_meetings_meeting_at ON public.meetings (meeting_at DESC);
CREATE INDEX idx_meeting_attendees_meeting_id ON public.meeting_attendees (meeting_id);
CREATE INDEX idx_meeting_decisions_meeting_id ON public.meeting_decisions (meeting_id);
CREATE INDEX idx_meeting_documents_meeting_id ON public.meeting_documents (meeting_id);

CREATE TRIGGER meetings_updated_at
  BEFORE UPDATE ON public.meetings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_document_signatures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meetings all" ON public.meetings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "meeting_attendees all" ON public.meeting_attendees FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "meeting_decisions all" ON public.meeting_decisions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "meeting_documents all" ON public.meeting_documents FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "meeting_document_signatures all" ON public.meeting_document_signatures FOR ALL USING (true) WITH CHECK (true);

-- Align RBAC: default `meetings` to same access as `events` when the key is missing.
UPDATE public.society_roles
SET permissions = jsonb_set(
  permissions,
  '{meetings}',
  COALESCE(permissions->'meetings', COALESCE(permissions->'events', 'false'::jsonb)),
  true
);
