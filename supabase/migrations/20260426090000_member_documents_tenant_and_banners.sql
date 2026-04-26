-- Multi-doc uploads for residents (photo IDs, tenant docs, service docs)
CREATE TABLE IF NOT EXISTS public.member_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  doc_kind text NOT NULL, -- photo_id | tenant_doc | service_doc
  doc_type text NOT NULL, -- e.g. aadhaar | pan | rental_agreement | other
  front_url text,
  back_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_member_documents_member_id ON public.member_documents(member_id);
CREATE INDEX IF NOT EXISTS idx_member_documents_kind ON public.member_documents(doc_kind);

ALTER TABLE public.member_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Member documents readable by all" ON public.member_documents;
DROP POLICY IF EXISTS "Member documents insertable by all" ON public.member_documents;
DROP POLICY IF EXISTS "Member documents updatable by all" ON public.member_documents;
DROP POLICY IF EXISTS "Member documents deletable by all" ON public.member_documents;
CREATE POLICY "Member documents readable by all" ON public.member_documents FOR SELECT USING (true);
CREATE POLICY "Member documents insertable by all" ON public.member_documents FOR INSERT WITH CHECK (true);
CREATE POLICY "Member documents updatable by all" ON public.member_documents FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Member documents deletable by all" ON public.member_documents FOR DELETE USING (true);

-- Occupancy model (owner may not live; tenant household may exist)
ALTER TABLE public.flats
  ADD COLUMN IF NOT EXISTS owner_lives_here boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS tenant_household_type text; -- family | unmarried_couple | friends | other

COMMENT ON COLUMN public.flats.owner_lives_here IS 'If false, owner is registered but not residing; tenant household may be living instead.';
COMMENT ON COLUMN public.flats.tenant_household_type IS 'Optional descriptor for tenant household composition.';

ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS household_group text NOT NULL DEFAULT 'owner';

COMMENT ON COLUMN public.members.household_group IS 'owner | tenant. Used to group flat members when owner does not reside but tenant household does.';

-- Login dashboard banners (admin managed)
CREATE TABLE IF NOT EXISTS public.society_dashboard_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  title text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_society_dashboard_banners_society_id ON public.society_dashboard_banners(society_id);

ALTER TABLE public.society_dashboard_banners ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Society banners readable by all" ON public.society_dashboard_banners;
DROP POLICY IF EXISTS "Society banners insertable by all" ON public.society_dashboard_banners;
DROP POLICY IF EXISTS "Society banners updatable by all" ON public.society_dashboard_banners;
DROP POLICY IF EXISTS "Society banners deletable by all" ON public.society_dashboard_banners;
CREATE POLICY "Society banners readable by all" ON public.society_dashboard_banners FOR SELECT USING (true);
CREATE POLICY "Society banners insertable by all" ON public.society_dashboard_banners FOR INSERT WITH CHECK (true);
CREATE POLICY "Society banners updatable by all" ON public.society_dashboard_banners FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Society banners deletable by all" ON public.society_dashboard_banners FOR DELETE USING (true);

