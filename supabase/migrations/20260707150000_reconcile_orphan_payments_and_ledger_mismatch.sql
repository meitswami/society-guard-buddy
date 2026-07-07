-- Reconcile finance ledger rows with linked maintenance payments and backfill
-- ledger entries for verified payments that were recorded without finance_entry_id.

-- 1) Legacy charges missing society_id (blocks ledger backfill for linked payments).
UPDATE public.maintenance_charges mc
SET society_id = (
  SELECT f.society_id
  FROM public.maintenance_payments mp
  JOIN public.flats f ON f.flat_number = mp.flat_number
  WHERE mp.charge_id = mc.id
    AND mp.payment_status = 'verified'
    AND f.society_id IS NOT NULL
  ORDER BY (
    SELECT COUNT(*)
    FROM public.maintenance_charges mc2
    WHERE mc2.society_id = f.society_id
  ) DESC
  LIMIT 1
)
WHERE mc.society_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.maintenance_payments mp
    WHERE mp.charge_id = mc.id
      AND mp.payment_status = 'verified'
      AND mp.finance_entry_id IS NULL
  );

-- 2) Align ledger totals / flat counts with linked verified payments.
WITH linked AS (
  SELECT
    fe.id AS finance_entry_id,
    COUNT(mp.id)::int AS payment_count,
    COALESCE(SUM(mp.amount), 0)::numeric AS payment_total,
    MIN(COALESCE(mp.due_date, mp.payment_date::date, mp.created_at::date))::date AS min_tx_date
  FROM public.finance_entries fe
  JOIN public.maintenance_payments mp ON mp.finance_entry_id = fe.id
  WHERE fe.record_mode = 'flats_only'
    AND fe.payment_status = 'verified'
    AND mp.payment_status = 'verified'
  GROUP BY fe.id
)
UPDATE public.finance_entries fe
SET
  total_amount = linked.payment_total,
  aggregate_flat_count = linked.payment_count,
  transaction_date = linked.min_tx_date
FROM linked
WHERE fe.id = linked.finance_entry_id
  AND (
    fe.aggregate_flat_count IS DISTINCT FROM linked.payment_count
    OR ABS(fe.total_amount - linked.payment_total) > 0.01
    OR fe.transaction_date IS DISTINCT FROM linked.min_tx_date
  );

-- 3) Rebuild allocations for flats_only ledger rows that have linked payments.
DELETE FROM public.finance_entry_allocations fea
WHERE fea.finance_entry_id IN (
  SELECT fe.id
  FROM public.finance_entries fe
  WHERE fe.record_mode = 'flats_only'
    AND EXISTS (
      SELECT 1
      FROM public.maintenance_payments mp
      WHERE mp.finance_entry_id = fe.id
        AND mp.payment_status = 'verified'
    )
);

INSERT INTO public.finance_entry_allocations (finance_entry_id, flat_id, flat_number, amount)
SELECT
  mp.finance_entry_id,
  f.id,
  mp.flat_number,
  mp.amount
FROM public.maintenance_payments mp
JOIN public.finance_entries fe ON fe.id = mp.finance_entry_id
LEFT JOIN public.flats f
  ON f.society_id = fe.society_id
 AND f.flat_number = mp.flat_number
WHERE fe.record_mode = 'flats_only'
  AND mp.payment_status = 'verified'
  AND mp.finance_entry_id IS NOT NULL;

-- 4) Create one ledger row per orphaned verified payment and link it.
DO $$
DECLARE
  rec RECORD;
  fe_id uuid;
  entry_month text;
  alloc_rows integer;
BEGIN
  FOR rec IN
    SELECT
      mp.id AS payment_id,
      mp.flat_number,
      mp.amount,
      mp.payment_method,
      mp.charge_id,
      mc.society_id,
      mc.title AS charge_title,
      COALESCE(mp.due_date, mp.payment_date::date, mp.created_at::date)::date AS tx_date
    FROM public.maintenance_payments mp
    JOIN public.maintenance_charges mc ON mc.id = mp.charge_id
    WHERE mp.payment_status = 'verified'
      AND mp.finance_entry_id IS NULL
      AND mc.society_id IS NOT NULL
    ORDER BY COALESCE(mp.due_date, mp.payment_date::date, mp.created_at::date), mp.flat_number
  LOOP
    entry_month := to_char(rec.tx_date, 'YYYY-MM');

    INSERT INTO public.finance_entries (
      society_id,
      record_mode,
      destination,
      allocation_style,
      include_vacant,
      entry_month,
      transaction_date,
      total_amount,
      aggregate_flat_count,
      charge_id,
      title,
      payment_method,
      payment_status,
      created_by
    ) VALUES (
      rec.society_id,
      'flats_only',
      'current_month_maintenance',
      'same_per_flat',
      false,
      entry_month,
      rec.tx_date,
      rec.amount,
      1,
      rec.charge_id,
      rec.charge_title,
      rec.payment_method,
      'verified',
      'Data migration'
    )
    RETURNING id INTO fe_id;

    INSERT INTO public.finance_entry_allocations (finance_entry_id, flat_id, flat_number, amount)
    SELECT fe_id, f.id, rec.flat_number, rec.amount
    FROM public.flats f
    WHERE f.society_id = rec.society_id
      AND f.flat_number = rec.flat_number
    LIMIT 1;

    GET DIAGNOSTICS alloc_rows = ROW_COUNT;
    IF alloc_rows = 0 THEN
      INSERT INTO public.finance_entry_allocations (finance_entry_id, flat_id, flat_number, amount)
      VALUES (fe_id, NULL, rec.flat_number, rec.amount);
    END IF;

    UPDATE public.maintenance_payments
    SET finance_entry_id = fe_id
    WHERE id = rec.payment_id;
  END LOOP;
END $$;
