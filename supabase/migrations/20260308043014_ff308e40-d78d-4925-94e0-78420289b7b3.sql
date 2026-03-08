
-- Flats table
CREATE TABLE public.flats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flat_number text NOT NULL UNIQUE,
  floor text,
  wing text,
  flat_type text DEFAULT 'residential',
  owner_name text,
  owner_phone text,
  intercom text,
  is_occupied boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.flats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Flats readable by all" ON public.flats FOR SELECT USING (true);
CREATE POLICY "Flats insertable by all" ON public.flats FOR INSERT WITH CHECK (true);
CREATE POLICY "Flats updatable by all" ON public.flats FOR UPDATE USING (true);
CREATE POLICY "Flats deletable by all" ON public.flats FOR DELETE USING (true);

-- Members table (linked to flats)
CREATE TABLE public.members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flat_id uuid REFERENCES public.flats(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  phone text,
  relation text DEFAULT 'owner',
  age integer,
  gender text,
  photo text,
  is_primary boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members readable by all" ON public.members FOR SELECT USING (true);
CREATE POLICY "Members insertable by all" ON public.members FOR INSERT WITH CHECK (true);
CREATE POLICY "Members updatable by all" ON public.members FOR UPDATE USING (true);
CREATE POLICY "Members deletable by all" ON public.members FOR DELETE USING (true);

-- Add flat_id to resident_vehicles for linking
ALTER TABLE public.resident_vehicles ADD COLUMN flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL;
