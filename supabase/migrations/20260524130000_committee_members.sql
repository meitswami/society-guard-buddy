-- Managing committee roster: name, position, photo, phone; optional representative for female members.

CREATE TABLE public.committee_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  name text NOT NULL,
  position text NOT NULL,
  phone text,
  gender text,
  photo text,
  show_representative boolean NOT NULL DEFAULT false,
  rep_name text,
  rep_phone text,
  rep_photo text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT committee_members_gender_check CHECK (
    gender IS NULL OR gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text])
  )
);

CREATE INDEX idx_committee_members_society_id ON public.committee_members (society_id);
CREATE INDEX idx_committee_members_sort ON public.committee_members (society_id, sort_order, name);

CREATE TRIGGER committee_members_updated_at
  BEFORE UPDATE ON public.committee_members
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.committee_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "committee_members all" ON public.committee_members FOR ALL USING (true) WITH CHECK (true);

-- RBAC: default `committee` to same access as `meetings` when the key is missing.
UPDATE public.society_roles
SET permissions = jsonb_set(
  permissions,
  '{committee}',
  COALESCE(permissions->'committee', COALESCE(permissions->'meetings', 'false'::jsonb)),
  true
);
