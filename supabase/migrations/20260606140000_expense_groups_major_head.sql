-- Major chart-of-accounts head for society payment expense groups (Finance → Record payment).

ALTER TABLE public.expense_groups
  ADD COLUMN IF NOT EXISTS major_head text;

COMMENT ON COLUMN public.expense_groups.major_head IS
  'Chart major head (SALARY & WAGES, OPERATION & MAINTENANCE, etc.) for group_kind = general.';

UPDATE public.expense_groups g
SET major_head = CASE
  WHEN trim(g.name) ~* 'corpus.*legal|legal.*corpus' THEN 'CORPUS FUND (LEGAL)'
  WHEN trim(g.name) ~* 'corpus|society fund' THEN 'SOCIETY CORPUS FUND'
  WHEN trim(g.name) ~* 'fixed deposit|\bfd\b' THEN 'FIXED DEPOSIT'
  WHEN trim(g.name) ~* '^bank\b|bank account' THEN 'BANK'
  WHEN trim(g.name) ~* '^cash\b|petty cash' THEN 'CASH'
  WHEN trim(g.name) ~* 'legal|professional|audit|advocate|lawyer' THEN 'LEGAL & PROFESSIONAL FEES'
  WHEN trim(g.name) ~* 'fixed asset|furniture|chair|equipment|machine|softner|softener|installation|asset' THEN 'FIXED ASSETS'
  WHEN trim(g.name) ~* 'salary|wage|security|guard|sweeper|cleaning|garden|housekeeping|house keeping|labour|labor' THEN 'SALARY & WAGES'
  WHEN trim(g.name) ~* 'electric|water|wifi|cctv|dg set|diesel|printing|maintenance|repair|insurance|lift|amc|utility' THEN 'OPERATION & MAINTENANCE'
  ELSE 'MISCELLANEOUS'
END
WHERE COALESCE(g.group_kind, 'event') = 'general'
  AND g.major_head IS NULL;

CREATE INDEX IF NOT EXISTS idx_expense_groups_major_head ON public.expense_groups (society_id, major_head)
  WHERE major_head IS NOT NULL;
