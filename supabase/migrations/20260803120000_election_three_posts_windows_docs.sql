-- Three-post elections: separate nomination/voting windows, winning vote thresholds,
-- nominee statements, and poll/election documents (circulars, letters, etc.).

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS nomination_starts_at timestamptz;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS nomination_ends_at timestamptz;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS winning_votes jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.polls.nomination_starts_at IS 'When self-nomination opens (admin-controlled).';
COMMENT ON COLUMN public.polls.nomination_ends_at IS 'When self-nomination closes (admin-controlled).';
COMMENT ON COLUMN public.polls.winning_votes IS 'Min Borda score per post to declare a winner, e.g. {"president":10,"secretary":10,"treasurer":10}.';

ALTER TABLE public.polls
  ALTER COLUMN open_posts SET DEFAULT '{"president":true,"secretary":true,"treasurer":true,"vice_president":false,"committee":false}'::jsonb;

ALTER TABLE public.poll_options
  ADD COLUMN IF NOT EXISTS nomination_statement text;

COMMENT ON COLUMN public.poll_options.nomination_statement IS 'Nominee pitch: why they should be chosen / preferred.';

CREATE TABLE IF NOT EXISTS public.poll_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  doc_kind text NOT NULL DEFAULT 'other',
  file_url text NOT NULL,
  file_name text,
  mime_type text,
  sort_order integer NOT NULL DEFAULT 0,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT poll_documents_doc_kind_check CHECK (
    doc_kind = ANY (ARRAY[
      'circular'::text,
      'letter'::text,
      'personal'::text,
      'society'::text,
      'other'::text
    ])
  )
);

CREATE INDEX IF NOT EXISTS idx_poll_documents_poll_id ON public.poll_documents (poll_id, sort_order, created_at);

ALTER TABLE public.poll_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "poll_documents all" ON public.poll_documents;
CREATE POLICY "poll_documents all" ON public.poll_documents FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.poll_documents TO anon, authenticated, service_role;
