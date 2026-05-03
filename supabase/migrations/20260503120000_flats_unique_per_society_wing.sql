-- Allow the same flat_number in different societies and across wings (A/B towers).
-- Replaces the global UNIQUE on flat_number with a scoped unique index.

ALTER TABLE public.flats DROP CONSTRAINT IF EXISTS flats_flat_number_key;

CREATE UNIQUE INDEX IF NOT EXISTS flats_society_flat_number_wing_uidx
  ON public.flats (society_id, flat_number, (COALESCE(trim(wing), '')));

COMMENT ON INDEX public.flats_society_flat_number_wing_uidx IS
  'Flat numbers may repeat across societies; within one society, wing disambiguates towers (e.g. 101 + A vs 101 + B).';
