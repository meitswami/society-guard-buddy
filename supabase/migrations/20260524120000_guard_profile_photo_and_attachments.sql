-- Guard worker profile photo + unlimited document attachments

ALTER TABLE public.guards
  ADD COLUMN IF NOT EXISTS photo_url text;

CREATE TABLE IF NOT EXISTS public.guard_attachments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  guard_id uuid NOT NULL REFERENCES public.guards(id) ON DELETE CASCADE,
  file_url text NOT NULL,
  file_name text,
  doc_label text NOT NULL DEFAULT 'Document',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.guard_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Guard attachments readable by all" ON public.guard_attachments;
CREATE POLICY "Guard attachments readable by all" ON public.guard_attachments FOR SELECT USING (true);
DROP POLICY IF EXISTS "Guard attachments insertable by all" ON public.guard_attachments;
CREATE POLICY "Guard attachments insertable by all" ON public.guard_attachments FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Guard attachments updatable by all" ON public.guard_attachments;
CREATE POLICY "Guard attachments updatable by all" ON public.guard_attachments FOR UPDATE USING (true);
DROP POLICY IF EXISTS "Guard attachments deletable by all" ON public.guard_attachments;
CREATE POLICY "Guard attachments deletable by all" ON public.guard_attachments FOR DELETE USING (true);
