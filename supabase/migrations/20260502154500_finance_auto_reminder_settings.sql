CREATE TABLE IF NOT EXISTS public.finance_reminder_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE UNIQUE,
  enabled boolean NOT NULL DEFAULT true,
  schedule text NOT NULL DEFAULT 'once_12pm' CHECK (schedule IN ('once_12pm', 'twice_12pm_7pm')),
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.finance_reminder_dispatch_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  charge_id uuid NOT NULL REFERENCES public.maintenance_charges(id) ON DELETE CASCADE,
  flat_number text NOT NULL,
  reminder_date date NOT NULL,
  reminder_slot text NOT NULL CHECK (reminder_slot IN ('12pm', '7pm')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, charge_id, flat_number, reminder_date, reminder_slot)
);

ALTER TABLE public.finance_reminder_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_reminder_dispatch_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All access finance_reminder_settings"
ON public.finance_reminder_settings
FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "All access finance_reminder_dispatch_log"
ON public.finance_reminder_dispatch_log
FOR ALL
USING (true)
WITH CHECK (true);
