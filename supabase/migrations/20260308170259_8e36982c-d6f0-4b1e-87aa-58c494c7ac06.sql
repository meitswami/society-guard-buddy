
-- Societies table
CREATE TABLE public.societies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text,
  city text,
  state text,
  pincode text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.societies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Societies readable by all" ON public.societies FOR SELECT USING (true);
CREATE POLICY "Societies insertable by all" ON public.societies FOR INSERT WITH CHECK (true);
CREATE POLICY "Societies updatable by all" ON public.societies FOR UPDATE USING (true);
CREATE POLICY "Societies deletable by all" ON public.societies FOR DELETE USING (true);

-- Super admins table
CREATE TABLE public.super_admins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  password text NOT NULL,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.super_admins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Super admins readable by all" ON public.super_admins FOR SELECT USING (true);
CREATE POLICY "Super admins insertable by all" ON public.super_admins FOR INSERT WITH CHECK (true);
CREATE POLICY "Super admins updatable by all" ON public.super_admins FOR UPDATE USING (true);

-- Society roles (custom per society)
CREATE TABLE public.society_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  role_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, role_name)
);

ALTER TABLE public.society_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Society roles readable by all" ON public.society_roles FOR SELECT USING (true);
CREATE POLICY "Society roles insertable by all" ON public.society_roles FOR INSERT WITH CHECK (true);
CREATE POLICY "Society roles updatable by all" ON public.society_roles FOR UPDATE USING (true);
CREATE POLICY "Society roles deletable by all" ON public.society_roles FOR DELETE USING (true);

-- Add society_id and role to admins
ALTER TABLE public.admins ADD COLUMN society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;
ALTER TABLE public.admins ADD COLUMN role_id uuid REFERENCES public.society_roles(id) ON DELETE SET NULL;

-- Add society_id to guards and flats for multi-society support
ALTER TABLE public.guards ADD COLUMN society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;
ALTER TABLE public.flats ADD COLUMN society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;

-- Default super admin (SUPERADMIN / super123)
INSERT INTO public.super_admins (username, password, name) VALUES ('SUPERADMIN', 'super123', 'Super Admin');
