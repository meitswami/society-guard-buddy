ALTER TABLE public.maintenance_payments
ADD COLUMN IF NOT EXISTS submitted_by text NOT NULL DEFAULT 'admin',
ADD COLUMN IF NOT EXISTS submitted_by_user_id uuid,
ADD COLUMN IF NOT EXISTS rejection_reason text,
ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

UPDATE public.maintenance_payments
SET submitted_by = COALESCE(NULLIF(submitted_by, ''), 'admin')
WHERE submitted_by IS NULL OR submitted_by = '';
