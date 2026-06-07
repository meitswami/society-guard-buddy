-- Event food receipts belong in Events & food only (not Finance → Transactions).
-- Link orphan food groups to calendar events and normalise categories.

-- 1) Food expenses must use event groups
UPDATE public.expense_groups g
SET group_kind = 'event'
WHERE g.id IN (
  SELECT DISTINCT e.group_id
  FROM public.expenses e
  WHERE e.expense_category = 'food'
    AND e.record_status = 'active'
)
AND COALESCE(g.group_kind, 'event') <> 'event';

-- 2) Reclassify any food rows still marked payment
UPDATE public.expenses e
SET expense_category = 'food'
WHERE e.record_status = 'active'
  AND e.expense_category IS DISTINCT FROM 'food'
  AND e.group_id IN (
    SELECT id FROM public.expense_groups WHERE COALESCE(group_kind, 'event') = 'event'
  );

-- 3) Link food groups missing event_id to the nearest calendar event (same society, within 14 days)
UPDATE public.expense_groups g
SET event_id = sub.event_id
FROM (
  SELECT DISTINCT ON (g2.id)
    g2.id AS group_id,
    ev.id AS event_id
  FROM public.expense_groups g2
  JOIN public.expenses ex ON ex.group_id = g2.id AND ex.expense_category = 'food' AND ex.record_status = 'active'
  JOIN public.events ev ON ev.society_id = g2.society_id
  WHERE g2.event_id IS NULL
    AND COALESCE(g2.group_kind, 'event') = 'event'
  ORDER BY g2.id, abs(ex.expense_date - ev.event_date::date)
) sub
WHERE g.id = sub.group_id
  AND g.event_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.expenses ex2
    JOIN public.events ev2 ON ev2.id = sub.event_id
    WHERE ex2.group_id = g.id
      AND abs(ex2.expense_date - ev2.event_date::date) <= 14
  );

-- 4) Ledger titles for food — consistent prefix for UI filtering
UPDATE public.finance_entries fe
SET title = 'Event food — ' || trim(ev.title)
FROM public.expenses ex
JOIN public.expense_groups g ON g.id = ex.group_id
JOIN public.events ev ON ev.id = g.event_id
WHERE fe.expense_id = ex.id
  AND ex.expense_category = 'food'
  AND g.event_id IS NOT NULL
  AND fe.title !~ '^Event food\s*[—–-]';

UPDATE public.finance_entry_counterparties cp
SET name = 'Event food: ' || trim(ev.title)
FROM public.finance_entries fe
JOIN public.expenses ex ON ex.id = fe.expense_id
JOIN public.expense_groups g ON g.id = ex.group_id
JOIN public.events ev ON ev.id = g.event_id
WHERE cp.finance_entry_id = fe.id
  AND ex.expense_category = 'food'
  AND cp.name NOT LIKE 'Event food:%';

NOTIFY pgrst, 'reload schema';
