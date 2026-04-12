
-- Link all existing data to the primary (legacy seed) society record
UPDATE flats SET society_id = '67d326db-6718-4509-ab9b-69d476b0305d' WHERE society_id IS NULL;
UPDATE guards SET society_id = '67d326db-6718-4509-ab9b-69d476b0305d' WHERE society_id IS NULL;
UPDATE admins SET society_id = '67d326db-6718-4509-ab9b-69d476b0305d' WHERE society_id IS NULL;
