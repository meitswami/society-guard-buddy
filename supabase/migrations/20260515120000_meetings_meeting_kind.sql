-- Meeting classification for filtering and reporting.

ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS meeting_kind text NOT NULL DEFAULT 'other';

ALTER TABLE public.meetings DROP CONSTRAINT IF EXISTS meetings_meeting_kind_check;

ALTER TABLE public.meetings
  ADD CONSTRAINT meetings_meeting_kind_check CHECK (
    meeting_kind = ANY (
      ARRAY[
        'general_body'::text,
        'annual'::text,
        'executive_committee'::text,
        'other'::text
      ]
    )
  );

COMMENT ON COLUMN public.meetings.meeting_kind IS 'general_body, annual, executive_committee, or other.';
