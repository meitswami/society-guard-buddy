-- Move recurring salt / softener consumable expenses to Water Softner Maintenance (O&M major head).
-- Keeps machine purchase and installation under the existing Water Softner (fixed asset) head.

INSERT INTO public.expense_groups (society_id, name, description, group_kind, major_head, created_by)
SELECT DISTINCT
  g.society_id,
  'Water Softner Maintenance',
  'Salt and recurring water softener upkeep (Operation & maintenance)',
  'general',
  'OPERATION & MAINTENANCE',
  'migration'
FROM public.expenses ex
JOIN public.expense_groups g ON g.id = ex.group_id
WHERE ex.record_status = 'active'
  AND ex.expense_category = 'payment'
  AND (
    ex.title ILIKE '%salt%soft%'
    OR ex.title ILIKE '%salt%softner%'
    OR ex.title ILIKE '%salt%softener%'
    OR ex.title ILIKE 'salt purchased%'
    OR ex.title ILIKE '%salt purchased%'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.expense_groups existing
    WHERE existing.society_id = g.society_id
      AND lower(trim(existing.name)) = lower(trim('Water Softner Maintenance'))
      AND COALESCE(existing.group_kind, 'general') = 'general'
  );

-- Reclassify salt / consumable payment rows
UPDATE public.expenses ex
SET group_id = maint.id
FROM public.expense_groups maint
WHERE maint.name = 'Water Softner Maintenance'
  AND COALESCE(maint.group_kind, 'general') = 'general'
  AND maint.major_head = 'OPERATION & MAINTENANCE'
  AND ex.group_id <> maint.id
  AND ex.record_status = 'active'
  AND ex.expense_category = 'payment'
  AND ex.group_id IN (
    SELECT g2.id FROM public.expense_groups g2 WHERE g2.society_id = maint.society_id
  )
  AND (
    ex.title ILIKE '%salt%soft%'
    OR ex.title ILIKE '%salt%softner%'
    OR ex.title ILIKE '%salt%softener%'
    OR ex.title ILIKE 'salt purchased%'
    OR ex.title ILIKE '%salt purchased%'
  );

-- Ledger titles for moved expenses
UPDATE public.finance_entries fe
SET title = trim(maint.name)
FROM public.expenses ex
JOIN public.expense_groups maint ON maint.id = ex.group_id
WHERE fe.expense_id = ex.id
  AND maint.name = 'Water Softner Maintenance'
  AND maint.major_head = 'OPERATION & MAINTENANCE'
  AND fe.title IS DISTINCT FROM trim(maint.name)
  AND fe.destination = 'separate_entry';

NOTIFY pgrst, 'reload schema';
