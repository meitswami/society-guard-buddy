-- Super admin: TOTP (Microsoft Authenticator), recovery email, updated default password
ALTER TABLE public.super_admins
  ADD COLUMN IF NOT EXISTS recovery_email text,
  ADD COLUMN IF NOT EXISTS totp_secret text,
  ADD COLUMN IF NOT EXISTS totp_enabled boolean NOT NULL DEFAULT false;

UPDATE public.super_admins
SET
  password = 'Hello#123',
  recovery_email = 'meit8swami@gmail.com'
WHERE username = 'SUPERADMIN';

-- One-time recovery codes (edge functions use service role; no client policies)
CREATE TABLE IF NOT EXISTS public.superadmin_recovery_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  super_admin_id uuid NOT NULL REFERENCES public.super_admins(id) ON DELETE CASCADE,
  code text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_superadmin_recovery_super_admin
  ON public.superadmin_recovery_challenges (super_admin_id);

ALTER TABLE public.superadmin_recovery_challenges ENABLE ROW LEVEL SECURITY;
