-- Timed member reveal: admins can unblur documents for 15s / 30s / 1min.

ALTER TABLE public.society_documents
  ADD COLUMN IF NOT EXISTS member_reveal_until timestamptz;

COMMENT ON COLUMN public.society_documents.member_reveal_until IS
  'When set and in the future, members can view the document without blur. Null or past = blurred for members.';

CREATE INDEX IF NOT EXISTS idx_society_documents_member_reveal_until
  ON public.society_documents (society_id, member_reveal_until)
  WHERE member_reveal_until IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'society_documents'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.society_documents;
  END IF;
END $$;
