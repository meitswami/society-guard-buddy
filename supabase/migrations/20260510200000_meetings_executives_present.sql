ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS executives_present text;

COMMENT ON COLUMN public.meetings.executives_present IS 'Committee / office-bearers recorded as present (free text, one per line).';
