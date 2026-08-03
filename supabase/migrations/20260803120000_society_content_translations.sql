-- Society-scoped bilingual content overrides (admin-editable for member display).
-- Falls back to app static translations when no row exists.

CREATE TABLE IF NOT EXISTS public.society_content_translations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  content_key text NOT NULL,
  text_en text NOT NULL DEFAULT '',
  text_hi text NOT NULL DEFAULT '',
  updated_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT society_content_translations_society_key UNIQUE (society_id, content_key)
);

CREATE INDEX IF NOT EXISTS idx_society_content_translations_society_id
  ON public.society_content_translations (society_id);

CREATE TRIGGER society_content_translations_updated_at
  BEFORE UPDATE ON public.society_content_translations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.society_content_translations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "society_content_translations all" ON public.society_content_translations;
CREATE POLICY "society_content_translations all" ON public.society_content_translations
  FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE public.society_content_translations IS
  'Per-society EN/HI overrides for member-facing copy (voting charter, help text). App static i18n is the default.';
