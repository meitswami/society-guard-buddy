-- Display order for meeting attachments (images, PDFs, etc.).

ALTER TABLE public.meeting_documents
  ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_meeting_documents_meeting_sort
  ON public.meeting_documents (meeting_id, sort_order, created_at);

-- Backfill stable order from creation time per meeting.
WITH ranked AS (
  SELECT
    id,
    row_number() OVER (PARTITION BY meeting_id ORDER BY created_at ASC) - 1 AS rn
  FROM public.meeting_documents
)
UPDATE public.meeting_documents d
SET sort_order = ranked.rn
FROM ranked
WHERE ranked.id = d.id;
