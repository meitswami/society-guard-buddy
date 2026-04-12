-- Default OFF: when enabled, residents may upload their own ID photos (matched by login phone) from Profile.
ALTER TABLE public.societies
  ADD COLUMN IF NOT EXISTS resident_self_id_upload_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.societies.resident_self_id_upload_enabled IS 'Lets household residents edit id_photo_front/back only for their member row (phone match); directory queries should omit ID fields for other flats.';
