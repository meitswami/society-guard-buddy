-- Standard duties chart: society-level period + duty rows with supervisor name(s).

CREATE TABLE public.committee_duties_charts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  period_from date NOT NULL,
  period_to date,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT committee_duties_charts_period_check CHECK (
    period_to IS NULL OR period_to >= period_from
  )
);

CREATE UNIQUE INDEX idx_committee_duties_charts_active_society
  ON public.committee_duties_charts (society_id)
  WHERE is_active = true;

CREATE INDEX idx_committee_duties_charts_society_id
  ON public.committee_duties_charts (society_id);

CREATE TRIGGER committee_duties_charts_updated_at
  BEFORE UPDATE ON public.committee_duties_charts
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.committee_duty_rows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chart_id uuid NOT NULL REFERENCES public.committee_duties_charts(id) ON DELETE CASCADE,
  duty_label text NOT NULL,
  supervisor_names text[] NOT NULL DEFAULT '{}',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_committee_duty_rows_chart_id
  ON public.committee_duty_rows (chart_id, sort_order);

CREATE TRIGGER committee_duty_rows_updated_at
  BEFORE UPDATE ON public.committee_duty_rows
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.committee_duties_charts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.committee_duty_rows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "committee_duties_charts all" ON public.committee_duties_charts
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "committee_duty_rows all" ON public.committee_duty_rows
  FOR ALL USING (true) WITH CHECK (true);
