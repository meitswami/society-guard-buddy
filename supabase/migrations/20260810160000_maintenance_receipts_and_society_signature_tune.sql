-- Maintenance receipt serial numbers (society-scoped, backfilled from all verified
-- payments) + enforce society signature tune on member-facing notifications.

-- ---------------------------------------------------------------------------
-- 1) Receipt serial columns + counter
-- ---------------------------------------------------------------------------
ALTER TABLE public.maintenance_payments
  ADD COLUMN IF NOT EXISTS receipt_seq integer,
  ADD COLUMN IF NOT EXISTS receipt_number text;

COMMENT ON COLUMN public.maintenance_payments.receipt_seq IS
  'Society-scoped sequential receipt number assigned when payment becomes verified.';
COMMENT ON COLUMN public.maintenance_payments.receipt_number IS
  'Display receipt number, e.g. MR-000186.';

CREATE TABLE IF NOT EXISTS public.society_maintenance_receipt_counters (
  society_id uuid PRIMARY KEY REFERENCES public.societies(id) ON DELETE CASCADE,
  last_seq integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.society_maintenance_receipt_counters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "society_maintenance_receipt_counters all" ON public.society_maintenance_receipt_counters;
CREATE POLICY "society_maintenance_receipt_counters all" ON public.society_maintenance_receipt_counters
  FOR ALL USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.maintenance_payment_society_id(p public.maintenance_payments)
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT mc.society_id FROM public.maintenance_charges mc WHERE mc.id = p.charge_id),
    (SELECT f.society_id FROM public.flats f WHERE f.id = p.flat_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.format_maintenance_receipt_number(seq integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 'MR-' || lpad(seq::text, 6, '0');
$$;

CREATE OR REPLACE FUNCTION public.assign_maintenance_receipt_number()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  sid uuid;
  next_seq integer;
BEGIN
  -- Keep an already-assigned serial forever (immutable receipt identity).
  IF NEW.receipt_seq IS NOT NULL AND NEW.receipt_number IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.payment_status IS DISTINCT FROM 'verified' THEN
    RETURN NEW;
  END IF;

  sid := public.maintenance_payment_society_id(NEW);
  IF sid IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.society_maintenance_receipt_counters (society_id, last_seq)
  VALUES (sid, 0)
  ON CONFLICT (society_id) DO NOTHING;

  UPDATE public.society_maintenance_receipt_counters
  SET last_seq = last_seq + 1,
      updated_at = now()
  WHERE society_id = sid
  RETURNING last_seq INTO next_seq;

  NEW.receipt_seq := next_seq;
  NEW.receipt_number := public.format_maintenance_receipt_number(next_seq);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_maintenance_receipt_number ON public.maintenance_payments;
CREATE TRIGGER trg_assign_maintenance_receipt_number
  BEFORE INSERT OR UPDATE OF payment_status, charge_id, flat_id
  ON public.maintenance_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_maintenance_receipt_number();

-- Society-scoped unique serial (expression via charge/flat may be null for orphans;
-- enforce with a partial unique index on (society via helper is not indexable easily).
-- Store society_id denormalized for uniqueness + reporting.
ALTER TABLE public.maintenance_payments
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES public.societies(id);

UPDATE public.maintenance_payments mp
SET society_id = public.maintenance_payment_society_id(mp)
WHERE society_id IS NULL;

CREATE OR REPLACE FUNCTION public.sync_maintenance_payment_society_id()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.society_id := public.maintenance_payment_society_id(NEW);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_maintenance_payment_society_id ON public.maintenance_payments;
CREATE TRIGGER trg_sync_maintenance_payment_society_id
  BEFORE INSERT OR UPDATE OF charge_id, flat_id
  ON public.maintenance_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_maintenance_payment_society_id();

-- Re-create receipt assign to also set society_id if missing
CREATE OR REPLACE FUNCTION public.assign_maintenance_receipt_number()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  sid uuid;
  next_seq integer;
BEGIN
  IF NEW.society_id IS NULL THEN
    NEW.society_id := public.maintenance_payment_society_id(NEW);
  END IF;

  IF NEW.receipt_seq IS NOT NULL AND COALESCE(NEW.receipt_number, '') <> '' THEN
    RETURN NEW;
  END IF;

  IF NEW.payment_status IS DISTINCT FROM 'verified' THEN
    RETURN NEW;
  END IF;

  sid := COALESCE(NEW.society_id, public.maintenance_payment_society_id(NEW));
  IF sid IS NULL THEN
    RETURN NEW;
  END IF;
  NEW.society_id := sid;

  INSERT INTO public.society_maintenance_receipt_counters (society_id, last_seq)
  VALUES (sid, 0)
  ON CONFLICT (society_id) DO NOTHING;

  UPDATE public.society_maintenance_receipt_counters
  SET last_seq = last_seq + 1,
      updated_at = now()
  WHERE society_id = sid
  RETURNING last_seq INTO next_seq;

  NEW.receipt_seq := next_seq;
  NEW.receipt_number := public.format_maintenance_receipt_number(next_seq);
  RETURN NEW;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS maintenance_payments_society_receipt_seq_uidx
  ON public.maintenance_payments (society_id, receipt_seq)
  WHERE receipt_seq IS NOT NULL AND society_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS maintenance_payments_receipt_number_uidx
  ON public.maintenance_payments (society_id, receipt_number)
  WHERE receipt_number IS NOT NULL AND society_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2) Backfill serials for ALL verified maintenance received so far
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
  next_seq integer;
BEGIN
  FOR r IN
    SELECT
      mp.id,
      COALESCE(mp.society_id, public.maintenance_payment_society_id(mp)) AS sid
    FROM public.maintenance_payments mp
    WHERE mp.payment_status = 'verified'
      AND mp.receipt_seq IS NULL
      AND COALESCE(mp.society_id, public.maintenance_payment_society_id(mp)) IS NOT NULL
    ORDER BY
      COALESCE(mp.society_id, public.maintenance_payment_society_id(mp)),
      COALESCE(mp.payment_date, mp.verified_at, mp.created_at),
      mp.created_at,
      mp.id
  LOOP
    INSERT INTO public.society_maintenance_receipt_counters (society_id, last_seq)
    VALUES (r.sid, 0)
    ON CONFLICT (society_id) DO NOTHING;

    UPDATE public.society_maintenance_receipt_counters
    SET last_seq = last_seq + 1,
        updated_at = now()
    WHERE society_id = r.sid
    RETURNING last_seq INTO next_seq;

    UPDATE public.maintenance_payments
    SET
      society_id = r.sid,
      receipt_seq = next_seq,
      receipt_number = public.format_maintenance_receipt_number(next_seq)
    WHERE id = r.id;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 3) Society signature tune on every member-facing notification
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_society_signature_notification_sound()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  sound_url text;
BEGIN
  IF NEW.society_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT s.admin_push_sound_url
  INTO sound_url
  FROM public.societies s
  WHERE s.id = NEW.society_id;

  IF sound_url IS NOT NULL AND btrim(sound_url) <> '' THEN
    NEW.sound_key := 'custom';
    NEW.sound_custom_url := sound_url;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_society_signature_notification_sound ON public.notifications;
CREATE TRIGGER trg_apply_society_signature_notification_sound
  BEFORE INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_society_signature_notification_sound();

COMMENT ON FUNCTION public.apply_society_signature_notification_sound() IS
  'Forces member notifications to use societies.admin_push_sound_url (society signature tune) when configured.';

NOTIFY pgrst, 'reload schema';
