-- Keep a single 7-member Aug 2026 committee (2-year tenure rows).
-- Duplicate open-ended office-bearer inserts are retired, not deleted.

UPDATE public.committee_members AS dup
SET
  is_active = false,
  updated_at = now()
FROM public.committee_members AS keep
WHERE dup.society_id = '67d326db-6718-4509-ab9b-69d476b0305d'
  AND keep.society_id = dup.society_id
  AND dup.is_active = true
  AND keep.is_active = true
  AND dup.id <> keep.id
  AND dup.term_from = '2026-08-14'
  AND keep.term_from = '2026-08-14'
  AND dup.term_to IS NULL
  AND keep.term_to IS NOT NULL
  AND lower(dup.position) = lower(keep.position);

UPDATE public.committee_members
SET
  name = CASE lower(position)
    WHEN 'president' THEN 'Suresh Pareek'
    WHEN 'vice-president' THEN 'Jaya Sharma'
    WHEN 'secretary' THEN 'Virendra Kumar Sharma'
    WHEN 'treasurer' THEN 'Anil Kumar Sharma'
    ELSE name
  END,
  sort_order = CASE lower(position)
    WHEN 'president' THEN 0
    WHEN 'vice-president' THEN 1
    WHEN 'secretary' THEN 2
    WHEN 'treasurer' THEN 3
    WHEN 'cultural secretary' THEN 4
    ELSE sort_order
  END,
  updated_at = now()
WHERE society_id = '67d326db-6718-4509-ab9b-69d476b0305d'
  AND is_active = true
  AND term_from = '2026-08-14'
  AND term_to IS NOT NULL;
