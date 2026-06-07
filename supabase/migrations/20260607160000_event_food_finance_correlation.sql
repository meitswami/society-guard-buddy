-- Correlate legacy Finance rows with calendar events (e.g. Holi Dinner Party):
-- contribution receipts → event_contributions; caterer bills → food expenses + event groups.
-- Also applies event/food scope normalisation from 20260607150000.

-- A) Fix events missing society_id (blocks Events & food module)
UPDATE public.events ev
SET society_id = f.society_id
FROM public.event_contributions ec
JOIN public.flats f ON f.id = ec.flat_id
WHERE ec.event_id = ev.id
  AND ev.society_id IS NULL
  AND f.society_id IS NOT NULL;

UPDATE public.events ev
SET society_id = fe.society_id
FROM public.finance_entries fe
WHERE ev.society_id IS NULL
  AND fe.society_id IS NOT NULL
  AND lower(fe.title) LIKE '%dinner%party%'
  AND lower(ev.title) LIKE '%dinner%party%'
  AND abs(COALESCE(fe.transaction_date, fe.created_at::date) - ev.event_date::date) <= 120;

-- B) Event food scope (from 20260607150000)
UPDATE public.expense_groups g
SET group_kind = 'event'
WHERE g.id IN (
  SELECT DISTINCT e.group_id
  FROM public.expenses e
  WHERE e.expense_category = 'food'
    AND e.record_status = 'active'
)
AND COALESCE(g.group_kind, 'event') <> 'event';

UPDATE public.expenses e
SET expense_category = 'food'
WHERE e.record_status = 'active'
  AND e.expense_category IS DISTINCT FROM 'food'
  AND e.group_id IN (
    SELECT id FROM public.expense_groups WHERE COALESCE(group_kind, 'event') = 'event'
  );

-- C) Classify finance rows that belong to calendar events
CREATE TEMP TABLE tmp_event_finance ON COMMIT DROP AS
SELECT DISTINCT ON (fe.id)
  fe.id AS finance_entry_id,
  ev.id AS event_id,
  trim(ev.title) AS event_title,
  fe.society_id,
  fe.total_amount,
  fe.destination,
  fe.notes,
  fe.payment_method,
  fe.screenshot_url,
  COALESCE(fe.transaction_date, fe.created_at::date) AS txn_date,
  fe.created_by,
  fe.created_at,
  fe.title AS fe_title,
  CASE
    WHEN fe.notes ~* 'trader|cater|vendor|kitchen|food|service|restaurant'
      OR EXISTS (
        SELECT 1
        FROM public.finance_entry_counterparties cp
        WHERE cp.finance_entry_id = fe.id
          AND cp.name ILIKE 'event food%'
      )
    THEN 'food_bill'
    WHEN fe.destination IN ('current_month_maintenance', 'separate_entry', 'corpus')
      AND fe.expense_id IS NULL
      AND NOT COALESCE(fe.notes, '') ~* 'trader|cater|vendor|kitchen|food|service|restaurant'
    THEN 'contribution'
    ELSE NULL
  END AS row_kind
FROM public.finance_entries fe
JOIN public.events ev ON ev.society_id = fe.society_id
WHERE fe.expense_id IS NULL
  AND (
    lower(fe.title) LIKE '%' || lower(ev.title) || '%'
    OR lower(replace(replace(fe.title, 'Holy', 'Holi'), '-', ' ')) LIKE '%' || lower(replace(ev.title, '-', ' ')) || '%'
    OR (
      lower(fe.title) LIKE '%dinner%party%'
      AND lower(ev.title) LIKE '%dinner%party%'
    )
  )
  AND abs(COALESCE(fe.transaction_date, fe.created_at::date) - ev.event_date::date) <= 120
ORDER BY fe.id, abs(COALESCE(fe.transaction_date, fe.created_at::date) - ev.event_date::date);

-- D) Food bill rows → expense group + food expense + link ledger
INSERT INTO public.expense_groups (society_id, name, event_id, group_kind, created_by, description)
SELECT DISTINCT
  tef.society_id,
  tef.event_title,
  tef.event_id,
  'event',
  COALESCE(tef.created_by, 'migration'),
  'Linked from finance (event food migration)'
FROM tmp_event_finance tef
WHERE tef.row_kind = 'food_bill'
  AND NOT EXISTS (
    SELECT 1
    FROM public.expense_groups g
    WHERE g.event_id = tef.event_id
      AND g.society_id = tef.society_id
  );

INSERT INTO public.expenses (
  group_id,
  title,
  total_amount,
  paid_by_flat,
  paid_by_flats,
  paid_by_name,
  split_type,
  payment_method,
  service_kind,
  vendor_or_service,
  expense_date,
  bill_screenshot_url,
  notes,
  expense_category,
  record_status
)
SELECT
  g.id,
  COALESCE(NULLIF(trim(tef.notes), ''), 'Caterer / food bill'),
  tef.total_amount,
  COALESCE(fea.flat_number, mp.flat_number, 'SOCIETY'),
  to_jsonb(ARRAY[COALESCE(fea.flat_number, mp.flat_number, 'SOCIETY')]),
  NULL,
  'equal',
  tef.payment_method,
  'one_time',
  NULLIF(trim(tef.notes), ''),
  tef.txn_date,
  tef.screenshot_url,
  'Migrated from finance entry fe:' || tef.finance_entry_id::text,
  'food',
  'active'
FROM tmp_event_finance tef
JOIN public.expense_groups g ON g.event_id = tef.event_id AND g.society_id = tef.society_id
LEFT JOIN public.finance_entry_allocations fea ON fea.finance_entry_id = tef.finance_entry_id
LEFT JOIN public.maintenance_payments mp ON mp.finance_entry_id = tef.finance_entry_id
WHERE tef.row_kind = 'food_bill'
  AND NOT EXISTS (
    SELECT 1
    FROM public.expenses ex
    WHERE ex.notes = 'Migrated from finance entry fe:' || tef.finance_entry_id::text
  );

UPDATE public.finance_entries fe
SET
  expense_id = ex.id,
  destination = 'separate_entry',
  title = 'Event food — ' || tef.event_title,
  record_mode = 'outsider_only'
FROM tmp_event_finance tef
JOIN public.expenses ex ON ex.notes = 'Migrated from finance entry fe:' || tef.finance_entry_id::text
WHERE fe.id = tef.finance_entry_id
  AND tef.row_kind = 'food_bill';

UPDATE public.finance_entry_counterparties cp
SET name = 'Event food: ' || tef.event_title
FROM tmp_event_finance tef
WHERE cp.finance_entry_id = tef.finance_entry_id
  AND tef.row_kind = 'food_bill'
  AND cp.name NOT LIKE 'Event food:%';

-- Remove mistaken maintenance receipts for caterer payments
DELETE FROM public.maintenance_payments mp
USING public.finance_entries fe
JOIN public.expenses ex ON ex.id = fe.expense_id
WHERE mp.finance_entry_id = fe.id
  AND ex.expense_category = 'food';

-- E) Contribution rows → event_contributions (per flat from maintenance_payments or allocations)
INSERT INTO public.event_contributions (
  event_id,
  flat_id,
  flat_number,
  amount,
  payment_method,
  transaction_id,
  screenshot_url,
  verified_by,
  verified_at
)
SELECT
  tef.event_id,
  src.flat_id,
  src.flat_number,
  src.amount,
  COALESCE(src.payment_method, tef.payment_method),
  'fe:' || tef.finance_entry_id::text,
  tef.screenshot_url,
  tef.created_by,
  tef.created_at
FROM tmp_event_finance tef
JOIN LATERAL (
  SELECT mp.flat_id, mp.flat_number, mp.amount, mp.payment_method
  FROM public.maintenance_payments mp
  WHERE mp.finance_entry_id = tef.finance_entry_id
  UNION ALL
  SELECT fea.flat_id, fea.flat_number, fea.amount, NULL::text
  FROM public.finance_entry_allocations fea
  WHERE fea.finance_entry_id = tef.finance_entry_id
    AND NOT EXISTS (
      SELECT 1 FROM public.maintenance_payments mp2 WHERE mp2.finance_entry_id = tef.finance_entry_id
    )
) src ON true
WHERE tef.row_kind = 'contribution'
  AND src.flat_number IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.event_contributions ec
    WHERE ec.transaction_id = 'fe:' || tef.finance_entry_id::text
      AND ec.flat_number = src.flat_number
  );

UPDATE public.finance_entries fe
SET
  title = 'Event contribution — ' || tef.event_title,
  destination = 'none'
FROM tmp_event_finance tef
WHERE fe.id = tef.finance_entry_id
  AND tef.row_kind = 'contribution';

-- F) Link orphan food groups to nearest event (within 14 days)
UPDATE public.expense_groups g
SET event_id = sub.event_id
FROM (
  SELECT DISTINCT ON (g2.id)
    g2.id AS group_id,
    ev.id AS event_id,
    ex.expense_date,
    ev.event_date
  FROM public.expense_groups g2
  JOIN public.expenses ex ON ex.group_id = g2.id AND ex.expense_category = 'food' AND ex.record_status = 'active'
  JOIN public.events ev ON ev.society_id = g2.society_id
  WHERE g2.event_id IS NULL
    AND COALESCE(g2.group_kind, 'event') = 'event'
    AND abs(ex.expense_date - ev.event_date::date) <= 14
  ORDER BY g2.id, abs(ex.expense_date - ev.event_date::date)
) sub
WHERE g.id = sub.group_id
  AND g.event_id IS NULL;

-- G) Normalise ledger titles for linked food expenses
UPDATE public.finance_entries fe
SET title = 'Event food — ' || trim(ev.title)
FROM public.expenses ex
JOIN public.expense_groups g ON g.id = ex.group_id
JOIN public.events ev ON ev.id = g.event_id
WHERE fe.expense_id = ex.id
  AND ex.expense_category = 'food'
  AND g.event_id IS NOT NULL
  AND fe.title !~ '^Event food\s*[—–-]';

NOTIFY pgrst, 'reload schema';
