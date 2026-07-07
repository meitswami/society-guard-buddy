-- Society documents: admin-managed files for members to view (protected viewer in app).

CREATE TABLE public.society_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  category text NOT NULL DEFAULT 'other',
  storage_path text NOT NULL,
  file_name text NOT NULL,
  mime_type text,
  published boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  uploaded_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT society_documents_category_check CHECK (
    category = ANY (ARRAY['bylaws'::text, 'minutes'::text, 'notices'::text, 'reports'::text, 'forms'::text, 'other'::text])
  )
);

CREATE INDEX idx_society_documents_society_id ON public.society_documents (society_id);
CREATE INDEX idx_society_documents_published ON public.society_documents (society_id, published, sort_order);

CREATE TRIGGER society_documents_updated_at
  BEFORE UPDATE ON public.society_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.society_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_documents all" ON public.society_documents
  FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE public.society_documents IS 'Society-level documents (bylaws, minutes, notices) — members view via protected in-app viewer only.';

-- Private bucket — no public URLs; app uses short-lived signed URLs.
INSERT INTO storage.buckets (id, name, public)
SELECT 'society-documents', 'society-documents', false
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'society-documents');

DROP POLICY IF EXISTS "society documents readable" ON storage.objects;
CREATE POLICY "society documents readable" ON storage.objects
  FOR SELECT USING (bucket_id = 'society-documents');

DROP POLICY IF EXISTS "society documents insertable" ON storage.objects;
CREATE POLICY "society documents insertable" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'society-documents');

DROP POLICY IF EXISTS "society documents updatable" ON storage.objects;
CREATE POLICY "society documents updatable" ON storage.objects
  FOR UPDATE USING (bucket_id = 'society-documents');

DROP POLICY IF EXISTS "society documents deletable" ON storage.objects;
CREATE POLICY "society documents deletable" ON storage.objects
  FOR DELETE USING (bucket_id = 'society-documents');

-- RBAC: default `documents` to same access as `meetings` when the key is missing.
UPDATE public.society_roles
SET permissions = jsonb_set(
  COALESCE(permissions, '{}'::jsonb),
  '{documents}',
  COALESCE(permissions->'documents', COALESCE(permissions->'meetings', 'false'::jsonb)),
  true
);
