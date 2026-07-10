ALTER TABLE public.finance_reminder_settings
  ADD COLUMN IF NOT EXISTS due_day integer NOT NULL DEFAULT 1
  CHECK (due_day >= 1 AND due_day <= 28);
