-- In-app / push sound selection (preset keys + optional society custom URL)
ALTER TABLE public.societies
  ADD COLUMN IF NOT EXISTS admin_push_sound_url text;

COMMENT ON COLUMN public.societies.admin_push_sound_url IS 'Optional society-wide custom alert sound (public URL), uploadable by admin only.';

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS sound_key text NOT NULL DEFAULT 'digital';

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS sound_custom_url text;

COMMENT ON COLUMN public.notifications.sound_key IS 'Preset: digital | chime | bell | custom';
COMMENT ON COLUMN public.notifications.sound_custom_url IS 'When sound_key = custom, public URL to audio file (usually society admin_push_sound_url at send time).';
