-- Kutumbika / default society: map 1xx–6xx flat numbers to 1st–6th floor (first digit = floor).
-- Does not change flats that do not match the 3-digit pattern (e.g. PH1, shops).

UPDATE public.flats
SET floor = CASE SUBSTRING(TRIM(flat_number) FROM 1 FOR 1)
  WHEN '1' THEN '1st Floor'
  WHEN '2' THEN '2nd Floor'
  WHEN '3' THEN '3rd Floor'
  WHEN '4' THEN '4th Floor'
  WHEN '5' THEN '5th Floor'
  WHEN '6' THEN '6th Floor'
  ELSE floor
END
WHERE society_id = '67d326db-6718-4509-ab9b-69d476b0305d'
  AND TRIM(flat_number) ~ '^[1-6][0-9]{2}$';
