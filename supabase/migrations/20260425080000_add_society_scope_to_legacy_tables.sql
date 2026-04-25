-- Add direct society scoping to legacy operational tables that previously relied on
-- flat_number or guard_id inference. This prevents cross-society leakage when flat
-- numbers overlap or when admins create rows without a guard session.

ALTER TABLE public.visitors
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;

ALTER TABLE public.blacklist
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;

ALTER TABLE public.guard_shifts
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;

ALTER TABLE public.resident_vehicles
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;

ALTER TABLE public.geofence_settings
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;

ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE;

-- Backfill rows that can be safely inferred.
UPDATE public.guard_shifts gs
SET society_id = g.society_id
FROM public.guards g
WHERE gs.society_id IS NULL
  AND gs.guard_id = g.guard_id
  AND g.society_id IS NOT NULL;

UPDATE public.resident_vehicles rv
SET society_id = f.society_id
FROM public.flats f
WHERE rv.society_id IS NULL
  AND rv.flat_id = f.id
  AND f.society_id IS NOT NULL;

UPDATE public.visitors v
SET society_id = g.society_id
FROM public.guards g
WHERE v.society_id IS NULL
  AND v.guard_id = g.guard_id
  AND g.society_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_visitors_society_id ON public.visitors(society_id);
CREATE INDEX IF NOT EXISTS idx_blacklist_society_id ON public.blacklist(society_id);
CREATE INDEX IF NOT EXISTS idx_guard_shifts_society_id ON public.guard_shifts(society_id);
CREATE INDEX IF NOT EXISTS idx_resident_vehicles_society_id ON public.resident_vehicles(society_id);
CREATE INDEX IF NOT EXISTS idx_geofence_settings_society_id ON public.geofence_settings(society_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_society_id ON public.audit_logs(society_id);
