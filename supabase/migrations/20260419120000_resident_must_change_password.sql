-- Primary resident first-login: prompt to set a new shared flat password (no current password).
ALTER TABLE public.resident_users
  ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.resident_users.must_change_password IS 'When true, primary resident must set a new password after login; applies to flat-wide password.';
