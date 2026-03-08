
-- Create update_updated_at function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Guards table
CREATE TABLE public.guards (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  guard_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  password TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.guards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Guards are readable by all" ON public.guards FOR SELECT USING (true);

-- Guard shifts table
CREATE TABLE public.guard_shifts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  guard_id TEXT NOT NULL,
  guard_name TEXT NOT NULL,
  login_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  logout_time TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.guard_shifts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shifts readable by all" ON public.guard_shifts FOR SELECT USING (true);
CREATE POLICY "Shifts insertable by all" ON public.guard_shifts FOR INSERT WITH CHECK (true);
CREATE POLICY "Shifts updatable by all" ON public.guard_shifts FOR UPDATE USING (true);

-- Visitors table
CREATE TABLE public.visitors (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  document_type TEXT NOT NULL DEFAULT 'other',
  document_number TEXT,
  document_photo TEXT,
  visitor_photos TEXT[] DEFAULT '{}',
  flat_number TEXT NOT NULL,
  purpose TEXT NOT NULL DEFAULT 'Visit',
  entry_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  exit_time TIMESTAMP WITH TIME ZONE,
  guard_id TEXT NOT NULL,
  guard_name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'visitor',
  company TEXT,
  vehicle_number TEXT,
  vehicle_photo TEXT,
  vehicle_entry_time TIMESTAMP WITH TIME ZONE,
  vehicle_exit_time TIMESTAMP WITH TIME ZONE,
  is_blacklisted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Visitors readable by all" ON public.visitors FOR SELECT USING (true);
CREATE POLICY "Visitors insertable by all" ON public.visitors FOR INSERT WITH CHECK (true);
CREATE POLICY "Visitors updatable by all" ON public.visitors FOR UPDATE USING (true);

CREATE TRIGGER update_visitors_updated_at BEFORE UPDATE ON public.visitors
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Resident vehicles table
CREATE TABLE public.resident_vehicles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  flat_number TEXT NOT NULL,
  resident_name TEXT NOT NULL,
  vehicle_number TEXT NOT NULL,
  vehicle_type TEXT NOT NULL DEFAULT 'car',
  vehicle_photo TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.resident_vehicles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Vehicles readable by all" ON public.resident_vehicles FOR SELECT USING (true);
CREATE POLICY "Vehicles insertable by all" ON public.resident_vehicles FOR INSERT WITH CHECK (true);
CREATE POLICY "Vehicles deletable by all" ON public.resident_vehicles FOR DELETE USING (true);

-- Blacklist table
CREATE TABLE public.blacklist (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'visitor',
  name TEXT,
  phone TEXT,
  vehicle_number TEXT,
  reason TEXT NOT NULL,
  added_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  added_by TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.blacklist ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Blacklist readable by all" ON public.blacklist FOR SELECT USING (true);
CREATE POLICY "Blacklist insertable by all" ON public.blacklist FOR INSERT WITH CHECK (true);
CREATE POLICY "Blacklist deletable by all" ON public.blacklist FOR DELETE USING (true);

-- Insert default guards
INSERT INTO public.guards (guard_id, name, password) VALUES
  ('G001', 'Rajesh Kumar', 'guard123'),
  ('G002', 'Suresh Singh', 'guard456'),
  ('G003', 'Amit Sharma', 'guard789');
