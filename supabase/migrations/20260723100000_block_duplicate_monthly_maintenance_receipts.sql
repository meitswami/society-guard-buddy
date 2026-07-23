-- Prevent double monthly-maintenance receipts for the same flat + billing month.
-- Also repair Flat 604: "June Monthly Maintenance" was saved with a July due_date,
-- which made June collection/audit disagree with the unpaid list.

-- 1) Repair known mismatch (charge title June, billing month July)
UPDATE public.maintenance_payments mp
SET due_date = '2026-06-19'
FROM public.maintenance_charges mc
WHERE mp.id = '847689a8-54e9-456e-a609-425c29f88cc5'
  AND mp.charge_id = mc.id
  AND mc.title = 'June Monthly Maintenance'
  AND mp.flat_number = '604'
  AND mp.due_date = '2026-07-19';

UPDATE public.finance_entries
SET entry_month = '2026-06',
    transaction_date = '2026-06-19',
    title = COALESCE(NULLIF(title, ''), 'June Monthly Maintenance')
WHERE id = '43fcbcb3-fe72-4e36-9698-640c33b4cf6a'
  AND entry_month = '2026-07';

-- 2) One verified/pending row per flat + charge + calendar month (by due_date)
CREATE UNIQUE INDEX IF NOT EXISTS maintenance_payments_flat_charge_month_uidx
ON public.maintenance_payments (
  flat_number,
  charge_id,
  (date_trunc('month', due_date::timestamp))
)
WHERE payment_status IN ('verified', 'pending')
  AND due_date IS NOT NULL
  AND charge_id IS NOT NULL;

-- 3) Block a second monthly-maintenance receipt for the same flat + billing month
--    even when the charge_id differs (e.g. "June…" recorded under a July due date).
CREATE OR REPLACE FUNCTION public.enforce_unique_monthly_maintenance_receipt()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  is_monthly_maint boolean;
  conflict_flat text;
BEGIN
  IF NEW.payment_status IS DISTINCT FROM 'verified'
     AND NEW.payment_status IS DISTINCT FROM 'pending' THEN
    RETURN NEW;
  END IF;

  IF NEW.due_date IS NULL OR NEW.charge_id IS NULL OR NEW.flat_number IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT (
    lower(coalesce(mc.frequency, '')) = 'monthly'
    AND position('maint' in lower(coalesce(mc.title, ''))) > 0
  )
  INTO is_monthly_maint
  FROM public.maintenance_charges mc
  WHERE mc.id = NEW.charge_id;

  IF NOT COALESCE(is_monthly_maint, false) THEN
    RETURN NEW;
  END IF;

  SELECT mp.flat_number
  INTO conflict_flat
  FROM public.maintenance_payments mp
  JOIN public.maintenance_charges mc ON mc.id = mp.charge_id
  WHERE mp.flat_number = NEW.flat_number
    AND mp.payment_status IN ('verified', 'pending')
    AND mp.due_date IS NOT NULL
    AND date_trunc('month', mp.due_date::timestamp) = date_trunc('month', NEW.due_date::timestamp)
    AND lower(coalesce(mc.frequency, '')) = 'monthly'
    AND position('maint' in lower(coalesce(mc.title, ''))) > 0
    AND (TG_OP = 'INSERT' OR mp.id IS DISTINCT FROM NEW.id)
  LIMIT 1;

  IF conflict_flat IS NOT NULL THEN
    RAISE EXCEPTION
      'Duplicate monthly maintenance receipt for flat % in billing month %',
      NEW.flat_number,
      to_char(NEW.due_date, 'YYYY-MM')
      USING ERRCODE = 'unique_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_unique_monthly_maintenance_receipt ON public.maintenance_payments;
CREATE TRIGGER trg_enforce_unique_monthly_maintenance_receipt
  BEFORE INSERT OR UPDATE OF flat_number, charge_id, due_date, payment_status
  ON public.maintenance_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_unique_monthly_maintenance_receipt();
