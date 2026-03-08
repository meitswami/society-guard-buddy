
-- Admins table
CREATE TABLE public.admins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id text NOT NULL UNIQUE,
  name text NOT NULL,
  password text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins readable by all" ON public.admins FOR SELECT USING (true);

-- Insert default admin
INSERT INTO public.admins (admin_id, name, password) VALUES ('ADMIN', 'Administrator', 'admin123');

-- Geofence settings table
CREATE TABLE public.geofence_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  radius_meters integer NOT NULL DEFAULT 500,
  set_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.geofence_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Geofence readable by all" ON public.geofence_settings FOR SELECT USING (true);
CREATE POLICY "Geofence insertable by all" ON public.geofence_settings FOR INSERT WITH CHECK (true);
CREATE POLICY "Geofence updatable by all" ON public.geofence_settings FOR UPDATE USING (true);
CREATE POLICY "Geofence deletable by all" ON public.geofence_settings FOR DELETE USING (true);
