
-- Add email to admins
ALTER TABLE admins ADD COLUMN IF NOT EXISTS email text;

-- Add email to resident_users
ALTER TABLE resident_users ADD COLUMN IF NOT EXISTS email text;

-- Add branding fields to societies
ALTER TABLE societies ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE societies ADD COLUMN IF NOT EXISTS contact_person text;
ALTER TABLE societies ADD COLUMN IF NOT EXISTS contact_email text;
ALTER TABLE societies ADD COLUMN IF NOT EXISTS contact_phone text;

-- Create biometric credentials table
CREATE TABLE IF NOT EXISTS biometric_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_type text NOT NULL,
  user_id uuid NOT NULL,
  credential_id text NOT NULL UNIQUE,
  public_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE biometric_credentials ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Biometric readable by all" ON biometric_credentials FOR SELECT USING (true);
CREATE POLICY "Biometric insertable by all" ON biometric_credentials FOR INSERT WITH CHECK (true);
CREATE POLICY "Biometric deletable by all" ON biometric_credentials FOR DELETE USING (true);
