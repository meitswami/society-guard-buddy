-- Saved user/custom report views over the metadata-driven reporting engine.

CREATE TABLE public.saved_report_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  report_id text NOT NULL,
  name text NOT NULL,
  description text,
  columns jsonb,
  filters jsonb NOT NULL DEFAULT '{}'::jsonb,
  sort jsonb,
  group_by jsonb,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT saved_report_definitions_name_len CHECK (char_length(trim(name)) > 0)
);

CREATE INDEX idx_saved_report_definitions_society
  ON public.saved_report_definitions (society_id, updated_at DESC);

CREATE INDEX idx_saved_report_definitions_society_report
  ON public.saved_report_definitions (society_id, report_id);

CREATE TRIGGER saved_report_definitions_updated_at
  BEFORE UPDATE ON public.saved_report_definitions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.saved_report_definitions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saved_report_definitions all"
  ON public.saved_report_definitions
  FOR ALL
  USING (true)
  WITH CHECK (true);
