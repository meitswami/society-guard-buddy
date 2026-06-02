-- Normalize finance ledger titles so period reports bucket by expense head, not generic event groups.

UPDATE public.finance_entries fe
SET
  title = CASE
    WHEN ex.expense_category = 'food' THEN
      COALESCE(
        'Event food — ' || NULLIF(trim(ev.title), ''),
        'Event food — ' || NULLIF(trim(g.name), ''),
        'Event food'
      )
    ELSE COALESCE(NULLIF(trim(g.name), ''), NULLIF(trim(ex.title), ''), 'Society payment')
  END,
  notes = trim(
    concat_ws(
      E'\n',
      NULLIF(fe.notes, ''),
      CASE
        WHEN ex.expense_category = 'payment'
          AND trim(ex.title) <> ''
          AND lower(trim(ex.title)) <> lower(trim(g.name))
          THEN 'Detail: ' || trim(ex.title)
        WHEN ex.expense_category = 'food'
          AND trim(ex.title) <> ''
          AND trim(ex.title) IS DISTINCT FROM trim(ev.title)
          AND trim(ex.title) IS DISTINCT FROM trim(g.name)
          THEN 'Item: ' || trim(ex.title)
        ELSE NULL
      END
    )
  )
FROM public.expenses ex
JOIN public.expense_groups g ON g.id = ex.group_id
LEFT JOIN public.events ev ON ev.id = g.event_id
WHERE fe.expense_id = ex.id
  AND fe.destination = 'separate_entry'
  AND fe.title ~ '^\[';
