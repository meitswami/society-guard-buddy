-- Guard daily duty: staff attendance, facility checks, and incident reports (tap-based, mobile-first).

CREATE TABLE public.guard_daily_duty (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  guard_uuid uuid NOT NULL REFERENCES public.guards(id) ON DELETE CASCADE,
  guard_id text NOT NULL,
  guard_name text NOT NULL,
  shift_id uuid NOT NULL REFERENCES public.guard_shifts(id) ON DELETE CASCADE,
  duty_date date NOT NULL DEFAULT (CURRENT_DATE),
  status text NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress', 'submitted')),
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT guard_daily_duty_shift_unique UNIQUE (shift_id)
);

CREATE INDEX idx_guard_daily_duty_society_date ON public.guard_daily_duty (society_id, duty_date DESC);
CREATE INDEX idx_guard_daily_duty_guard ON public.guard_daily_duty (guard_uuid, duty_date DESC);

CREATE TRIGGER guard_daily_duty_updated_at
  BEFORE UPDATE ON public.guard_daily_duty
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.guard_duty_staff_attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  duty_id uuid NOT NULL REFERENCES public.guard_daily_duty(id) ON DELETE CASCADE,
  staff_role text NOT NULL,
  staff_name text,
  status text NOT NULL DEFAULT 'not_marked'
    CHECK (status IN ('present', 'absent', 'late', 'half_day', 'not_required', 'not_marked')),
  absence_reason text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT guard_duty_staff_role_unique UNIQUE (duty_id, staff_role)
);

CREATE INDEX idx_guard_duty_staff_duty ON public.guard_duty_staff_attendance (duty_id);

CREATE TABLE public.guard_duty_system_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  duty_id uuid NOT NULL REFERENCES public.guard_daily_duty(id) ON DELETE CASCADE,
  check_key text NOT NULL,
  status text NOT NULL DEFAULT 'not_checked'
    CHECK (status IN ('ok', 'problem', 'not_working', 'not_checked')),
  problem_preset text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT guard_duty_check_unique UNIQUE (duty_id, check_key)
);

CREATE INDEX idx_guard_duty_checks_duty ON public.guard_duty_system_checks (duty_id);

CREATE TABLE public.guard_duty_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  duty_id uuid NOT NULL REFERENCES public.guard_daily_duty(id) ON DELETE CASCADE,
  category text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low', 'medium', 'high')),
  flat_number text,
  problem_preset text,
  photo_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_guard_duty_incidents_duty ON public.guard_duty_incidents (duty_id);
CREATE INDEX idx_guard_duty_incidents_category ON public.guard_duty_incidents (duty_id, category);

ALTER TABLE public.guard_daily_duty ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guard_duty_staff_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guard_duty_system_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guard_duty_incidents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "guard_daily_duty all" ON public.guard_daily_duty FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "guard_duty_staff all" ON public.guard_duty_staff_attendance FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "guard_duty_checks all" ON public.guard_duty_system_checks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "guard_duty_incidents all" ON public.guard_duty_incidents FOR ALL USING (true) WITH CHECK (true);
