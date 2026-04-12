-- Tenant / staff / other: ID photos, police verification, spouse, dates; staff vehicles linked to member
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS id_photo_front text,
  ADD COLUMN IF NOT EXISTS id_photo_back text,
  ADD COLUMN IF NOT EXISTS police_verification text,
  ADD COLUMN IF NOT EXISTS spouse_name text,
  ADD COLUMN IF NOT EXISTS date_joining date,
  ADD COLUMN IF NOT EXISTS date_leave date;

COMMENT ON COLUMN public.members.police_verification IS 'Optional status or note, e.g. pending | verified';

ALTER TABLE public.resident_vehicles
  ADD COLUMN IF NOT EXISTS member_id uuid REFERENCES public.members(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS vehicle_color text,
  ADD COLUMN IF NOT EXISTS vehicle_display_name text;

CREATE INDEX IF NOT EXISTS idx_resident_vehicles_member_id ON public.resident_vehicles(member_id);

DROP POLICY IF EXISTS "Vehicles updatable by all" ON public.resident_vehicles;
CREATE POLICY "Vehicles updatable by all" ON public.resident_vehicles FOR UPDATE USING (true) WITH CHECK (true);
