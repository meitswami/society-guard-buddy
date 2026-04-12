-- Link all existing data to the primary (legacy seed) society record.
-- Fresh databases have no row with this id yet — create it so FK updates succeed.
INSERT INTO public.societies (
  id,
  name,
  address,
  city,
  state,
  pincode,
  is_active,
  created_at,
  logo_url,
  contact_person,
  contact_email,
  contact_phone
)
VALUES (
  '67d326db-6718-4509-ab9b-69d476b0305d',
  'Evergreen heights',
  NULL,
  'Jaipur',
  'Rajasthan',
  '302020',
  true,
  '2026-03-08T18:26:46.646947+00:00',
  NULL,
  'Meit',
  'meit8swami@gmail.com',
  '8619436041'
)
ON CONFLICT (id) DO NOTHING;

UPDATE flats SET society_id = '67d326db-6718-4509-ab9b-69d476b0305d' WHERE society_id IS NULL;
UPDATE guards SET society_id = '67d326db-6718-4509-ab9b-69d476b0305d' WHERE society_id IS NULL;
UPDATE admins SET society_id = '67d326db-6718-4509-ab9b-69d476b0305d' WHERE society_id IS NULL;
