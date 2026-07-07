-- Backfill finance ledger rows for payment expenses that were saved without a ledger entry
-- (typically caused by equal-split rounding drift before remainder fix).

-- 1) Fix split rounding drift so split totals match expense totals.
WITH drift AS (
  SELECT
    e.id AS expense_id,
    e.total_amount::numeric AS total,
    es.id AS split_id,
    es.amount::numeric AS amount,
    ROW_NUMBER() OVER (PARTITION BY e.id ORDER BY es.flat_number DESC) AS rn,
    SUM(es.amount::numeric) OVER (PARTITION BY e.id) AS split_sum
  FROM expenses e
  JOIN expense_splits es ON es.expense_id = e.id
  LEFT JOIN finance_entries fe ON fe.expense_id = e.id
  WHERE e.expense_category = 'payment'
    AND e.record_status = 'active'
    AND fe.id IS NULL
    AND e.split_type <> 'society_fund'
)
UPDATE expense_splits es
SET amount = ROUND(d.amount + (d.total - d.split_sum), 2)
FROM drift d
WHERE es.id = d.split_id
  AND d.rn = 1
  AND ABS(d.total - d.split_sum) BETWEEN 0.01 AND 1.00;

-- 2) Insert missing finance_entries + counterparties + allocations for payment expenses.
DO $$
DECLARE
  rec RECORD;
  fe_id uuid;
  paid_by text;
  counterparty_relation text;
  ledger_notes text;
  alloc_style text;
BEGIN
  FOR rec IN
    SELECT
      e.id AS expense_id,
      eg.society_id,
      e.title,
      e.total_amount::numeric AS total_amount,
      e.expense_date,
      e.payment_method,
      e.notes,
      e.vendor_or_service,
      e.paid_by_name,
      e.paid_by_flats,
      e.split_type,
      eg.name AS group_name
    FROM expenses e
    JOIN expense_groups eg ON eg.id = e.group_id
    LEFT JOIN finance_entries fe ON fe.expense_id = e.id
    WHERE e.expense_category = 'payment'
      AND e.record_status = 'active'
      AND fe.id IS NULL
  LOOP
    paid_by := COALESCE(
      NULLIF(array_to_string(ARRAY(SELECT jsonb_array_elements_text(rec.paid_by_flats::jsonb)), ', '), ''),
      'SOCIETY'
    );

    IF rec.split_type = 'society_fund' THEN
      counterparty_relation := 'Society fund (no per-flat split)';
    ELSE
      counterparty_relation := 'Advanced by flat(s): ' || paid_by;
    END IF;

    ledger_notes := NULL;
    IF rec.title IS NOT NULL AND btrim(rec.title) <> '' THEN
      ledger_notes := 'Detail: ' || btrim(rec.title);
    END IF;
    IF rec.notes IS NOT NULL AND btrim(rec.notes) <> '' THEN
      ledger_notes := COALESCE(ledger_notes || E'\n', '') || btrim(rec.notes);
    END IF;
    IF rec.vendor_or_service IS NOT NULL AND btrim(rec.vendor_or_service) <> '' THEN
      ledger_notes := COALESCE(ledger_notes || E'\n', '') || 'Vendor: ' || btrim(rec.vendor_or_service);
    END IF;

    SELECT CASE
      WHEN COUNT(DISTINCT es.amount) = 1 AND COUNT(*) > 0 THEN 'split_total_equally'
      ELSE 'none'
    END
    INTO alloc_style
    FROM expense_splits es
    WHERE es.expense_id = rec.expense_id;

    IF rec.split_type = 'society_fund' THEN
      alloc_style := 'none';
    END IF;

    INSERT INTO finance_entries (
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
      expense_id
    ) VALUES (
      rec.society_id,
      'outsider_only',
      'separate_entry',
      COALESCE(alloc_style, 'none'),
      false,
      to_char(rec.expense_date::date, 'YYYY-MM'),
      rec.expense_date::date,
      rec.total_amount,
      CASE
        WHEN rec.split_type = 'society_fund' THEN 1
        ELSE (SELECT COUNT(*)::int FROM expense_splits es WHERE es.expense_id = rec.expense_id)
      END,
      NULL,
      rec.group_name,
      ledger_notes,
      NULL,
      NULL,
      rec.payment_method,
      'verified',
      COALESCE(rec.paid_by_name, 'Administrator'),
      rec.expense_id
    )
    RETURNING id INTO fe_id;

    INSERT INTO finance_entry_counterparties (finance_entry_id, name, relation_to_society)
    VALUES (
      fe_id,
      'Society payment: ' || rec.group_name,
      counterparty_relation
    );

    IF rec.split_type = 'society_fund' THEN
      INSERT INTO finance_entry_allocations (finance_entry_id, flat_id, flat_number, amount)
      VALUES (fe_id, NULL, 'SOCIETY', rec.total_amount);
    ELSE
      INSERT INTO finance_entry_allocations (finance_entry_id, flat_id, flat_number, amount)
      SELECT
        fe_id,
        f.id,
        es.flat_number,
        es.amount
      FROM expense_splits es
      LEFT JOIN flats f ON f.society_id = rec.society_id AND f.flat_number = es.flat_number
      WHERE es.expense_id = rec.expense_id;
    END IF;
  END LOOP;
END $$;
