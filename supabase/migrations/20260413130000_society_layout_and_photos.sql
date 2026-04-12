-- Society building layout, flat numbering hints, and multiple photos (superadmin-managed)

ALTER TABLE public.societies
  ADD COLUMN IF NOT EXISTS photo_urls text[] NOT NULL DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS total_flats integer,
  ADD COLUMN IF NOT EXISTS total_floors integer,
  ADD COLUMN IF NOT EXISTS block_names text[],
  ADD COLUMN IF NOT EXISTS terrace_accessible boolean,
  ADD COLUMN IF NOT EXISTS has_basement boolean,
  ADD COLUMN IF NOT EXISTS basement_usable_for_residents boolean,
  ADD COLUMN IF NOT EXISTS flats_per_floor integer,
  ADD COLUMN IF NOT EXISTS flat_series_start text,
  ADD COLUMN IF NOT EXISTS flat_series_end text;

-- Public bucket for society gallery images (same access pattern as notification-media / guard-documents)
INSERT INTO storage.buckets (id, name, public)
SELECT 'society-photos', 'society-photos', true
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'society-photos');

DROP POLICY IF EXISTS "society photos readable" ON storage.objects;
CREATE POLICY "society photos readable" ON storage.objects FOR SELECT USING (bucket_id = 'society-photos');

DROP POLICY IF EXISTS "society photos insertable" ON storage.objects;
CREATE POLICY "society photos insertable" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'society-photos');

DROP POLICY IF EXISTS "society photos updatable" ON storage.objects;
CREATE POLICY "society photos updatable" ON storage.objects FOR UPDATE USING (bucket_id = 'society-photos');

DROP POLICY IF EXISTS "society photos deletable" ON storage.objects;
CREATE POLICY "society photos deletable" ON storage.objects FOR DELETE USING (bucket_id = 'society-photos');
