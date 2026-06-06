-- Move legacy non-food rows out of Events & food into Finance → Record payment (society payment heads).
-- Keeps only the "Food Expenses" group under event / food category.

-- 1) Expense groups: event → general (except Food Expenses)
UPDATE public.expense_groups g
SET
  group_kind = 'general',
  event_id = NULL
WHERE COALESCE(g.group_kind, 'event') = 'event'
  AND trim(g.name) <> 'Food Expenses';

-- 2) Expenses: reclassify as payment (non-food)
UPDATE public.expenses e
SET expense_category = 'payment'
FROM public.expense_groups g
WHERE e.group_id = g.id
  AND e.record_status = 'active'
  AND trim(g.name) <> 'Food Expenses'
  AND e.expense_category IS DISTINCT FROM 'payment';

-- 3) Existing finance ledger rows: fix titles / notes (Event food → expense head)
UPDATE public.finance_entries fe
SET
  title = COALESCE(NULLIF(trim(g.name), ''), NULLIF(trim(ex.title), ''), 'Society payment'),
  notes = trim(
    concat_ws(
      E'\n',
      NULLIF(
        regexp_replace(fe.notes, '^Item: ', 'Detail: '),
        ''
      ),
      CASE
        WHEN trim(ex.title) <> ''
          AND lower(trim(ex.title)) <> lower(trim(g.name))
          THEN 'Detail: ' || trim(ex.title)
        ELSE NULL
      END,
      CASE
        WHEN trim(ex.vendor_or_service) <> '' THEN 'Vendor: ' || trim(ex.vendor_or_service)
        ELSE NULL
      END
    )
  )
FROM public.expenses ex
JOIN public.expense_groups g ON g.id = ex.group_id
WHERE fe.expense_id = ex.id
  AND fe.destination = 'separate_entry'
  AND trim(g.name) <> 'Food Expenses'
  AND (
    fe.title ~ '^Event food\s*[—–-]'
    OR fe.title ~ '^\['
  );

-- 4) Counterparties: Splitwise / Event food → Society payment
UPDATE public.finance_entry_counterparties cp
SET
  name = 'Society payment: ' || trim(g.name),
  relation_to_society = CASE
    WHEN ex.split_type = 'society_fund' THEN 'Society fund (no per-flat split)'
    ELSE cp.relation_to_society
  END
FROM public.finance_entries fe
JOIN public.expenses ex ON ex.id = fe.expense_id
JOIN public.expense_groups g ON g.id = ex.group_id
WHERE cp.finance_entry_id = fe.id
  AND trim(g.name) <> 'Food Expenses'
  AND (
    cp.name LIKE 'Splitwise:%'
    OR cp.name LIKE 'Event food:%'
    OR cp.name NOT LIKE 'Society payment:%'
  );

-- 5) Missing finance_entries for society-fund payment expenses (no ledger yet)
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
  notes,
  screenshot_url,
  transaction_id,
  payment_method,
  payment_status,
  created_by,
  created_at,
  expense_id
)
SELECT
  g.society_id,
  'outsider_only',
  'separate_entry',
  'none',
  false,
  to_char(ex.expense_date, 'YYYY-MM'),
  ex.expense_date,
  ex.total_amount,
  1,
  NULL,
  COALESCE(NULLIF(trim(g.name), ''), NULLIF(trim(ex.title), ''), 'Society payment'),
  trim(
    concat_ws(
      E'\n',
      CASE
        WHEN trim(ex.title) <> ''
          AND lower(trim(ex.title)) <> lower(trim(g.name))
          THEN 'Detail: ' || trim(ex.title)
        ELSE NULL
      END,
      NULLIF(trim(ex.notes), ''),
      CASE
        WHEN trim(ex.vendor_or_service) <> '' THEN 'Vendor: ' || trim(ex.vendor_or_service)
        ELSE NULL
      END
    )
  ),
  ex.bill_screenshot_url,
  NULL,
  ex.payment_method,
  'verified',
  COALESCE(ex.paid_by_name, 'Migration'),
  COALESCE(ex.created_at, now()),
  ex.id
FROM public.expenses ex
JOIN public.expense_groups g ON g.id = ex.group_id
LEFT JOIN public.finance_entries fe ON fe.expense_id = ex.id
WHERE ex.record_status = 'active'
  AND trim(g.name) <> 'Food Expenses'
  AND ex.split_type = 'society_fund'
  AND fe.id IS NULL;

-- 6) Counterparties for newly inserted ledger rows
INSERT INTO public.finance_entry_counterparties (finance_entry_id, name, relation_to_society)
SELECT
  fe.id,
  'Society payment: ' || trim(g.name),
  'Society fund (no per-flat split)'
FROM public.finance_entries fe
JOIN public.expenses ex ON ex.id = fe.expense_id
JOIN public.expense_groups g ON g.id = ex.group_id
LEFT JOIN public.finance_entry_counterparties cp ON cp.finance_entry_id = fe.id
WHERE cp.id IS NULL
  AND trim(g.name) <> 'Food Expenses'
  AND ex.split_type = 'society_fund';

-- 7) Allocations: SOCIETY bucket for society-fund rows missing allocations
INSERT INTO public.finance_entry_allocations (finance_entry_id, flat_id, flat_number, amount)
SELECT
  fe.id,
  NULL,
  'SOCIETY',
  ex.total_amount
FROM public.finance_entries fe
JOIN public.expenses ex ON ex.id = fe.expense_id
JOIN public.expense_groups g ON g.id = ex.group_id
WHERE trim(g.name) <> 'Food Expenses'
  AND ex.split_type = 'society_fund'
  AND NOT EXISTS (
    SELECT 1 FROM public.finance_entry_allocations a WHERE a.finance_entry_id = fe.id
  );

NOTIFY pgrst, 'reload schema';
