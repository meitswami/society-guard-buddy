-- Platform-wide branding for Flutter mobile apps (logo + colors).
-- Managed from Superadmin → Settings. Web resident UI is unchanged.

CREATE TABLE IF NOT EXISTS public.platform_branding (
  id text PRIMARY KEY DEFAULT 'default',
  app_name text NOT NULL DEFAULT 'Kutumbika',
  tagline text DEFAULT '— parivaar jaisi society —',
  logo_url text,
  primary_color text NOT NULL DEFAULT '#F58220',
  primary_dark_color text NOT NULL DEFAULT '#E08E10',
  background_color text NOT NULL DEFAULT '#F8F7F4',
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.platform_branding ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "platform branding readable" ON public.platform_branding;
CREATE POLICY "platform branding readable" ON public.platform_branding
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "platform branding writable" ON public.platform_branding;
CREATE POLICY "platform branding writable" ON public.platform_branding
  FOR ALL USING (true) WITH CHECK (true);

INSERT INTO public.platform_branding (id)
VALUES ('default')
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
SELECT 'platform-assets', 'platform-assets', true
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'platform-assets');

DROP POLICY IF EXISTS "platform assets readable" ON storage.objects;
CREATE POLICY "platform assets readable" ON storage.objects
  FOR SELECT USING (bucket_id = 'platform-assets');

DROP POLICY IF EXISTS "platform assets insertable" ON storage.objects;
CREATE POLICY "platform assets insertable" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'platform-assets');

DROP POLICY IF EXISTS "platform assets updatable" ON storage.objects;
CREATE POLICY "platform assets updatable" ON storage.objects
  FOR UPDATE USING (bucket_id = 'platform-assets');

DROP POLICY IF EXISTS "platform assets deletable" ON storage.objects;
CREATE POLICY "platform assets deletable" ON storage.objects
  FOR DELETE USING (bucket_id = 'platform-assets');
