
-- Add new columns to guards table
ALTER TABLE public.guards
  ADD COLUMN IF NOT EXISTS auth_mode text NOT NULL DEFAULT 'password',
  ADD COLUMN IF NOT EXISTS police_verification text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS police_verification_date date,
  ADD COLUMN IF NOT EXISTS kyc_alert_days integer NOT NULL DEFAULT 7,
  ADD COLUMN IF NOT EXISTS phone text;

-- Create guard_documents table
CREATE TABLE IF NOT EXISTS public.guard_documents (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  guard_id uuid NOT NULL REFERENCES public.guards(id) ON DELETE CASCADE,
  doc_label text NOT NULL DEFAULT 'ID Card',
  front_url text,
  back_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.guard_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Guard docs readable by all" ON public.guard_documents;
CREATE POLICY "Guard docs readable by all" ON public.guard_documents FOR SELECT USING (true);
DROP POLICY IF EXISTS "Guard docs insertable by all" ON public.guard_documents;
CREATE POLICY "Guard docs insertable by all" ON public.guard_documents FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Guard docs updatable by all" ON public.guard_documents;
CREATE POLICY "Guard docs updatable by all" ON public.guard_documents FOR UPDATE USING (true);
DROP POLICY IF EXISTS "Guard docs deletable by all" ON public.guard_documents;
CREATE POLICY "Guard docs deletable by all" ON public.guard_documents FOR DELETE USING (true);

-- Create storage bucket for guard documents (skip if already present — e.g. dashboard or retry)
INSERT INTO storage.buckets (id, name, public)
VALUES ('guard-documents', 'guard-documents', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Guard docs storage readable" ON storage.objects;
CREATE POLICY "Guard docs storage readable" ON storage.objects FOR SELECT USING (bucket_id = 'guard-documents');
DROP POLICY IF EXISTS "Guard docs storage insertable" ON storage.objects;
CREATE POLICY "Guard docs storage insertable" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'guard-documents');
DROP POLICY IF EXISTS "Guard docs storage updatable" ON storage.objects;
CREATE POLICY "Guard docs storage updatable" ON storage.objects FOR UPDATE USING (bucket_id = 'guard-documents');
DROP POLICY IF EXISTS "Guard docs storage deletable" ON storage.objects;
CREATE POLICY "Guard docs storage deletable" ON storage.objects FOR DELETE USING (bucket_id = 'guard-documents');
