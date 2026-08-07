-- Official society letterhead / report settings (multi-society scoped)
ALTER TABLE public.societies
  ADD COLUMN IF NOT EXISTS letterhead_storage_path text,
  ADD COLUMN IF NOT EXISTS letterhead_left_mm numeric NOT NULL DEFAULT 19.05,
  ADD COLUMN IF NOT EXISTS letterhead_right_mm numeric NOT NULL DEFAULT 19.05,
  ADD COLUMN IF NOT EXISTS default_report_format text NOT NULL DEFAULT 'letterhead';

ALTER TABLE public.societies
  DROP CONSTRAINT IF EXISTS societies_default_report_format_check;

ALTER TABLE public.societies
  ADD CONSTRAINT societies_default_report_format_check
  CHECK (default_report_format IN ('letterhead', 'plain'));

ALTER TABLE public.societies
  DROP CONSTRAINT IF EXISTS societies_letterhead_mode_check;

ALTER TABLE public.societies
  ADD CONSTRAINT societies_letterhead_mode_check
  CHECK (letterhead_mode IN ('auto', 'image', 'stationery'));

COMMENT ON COLUMN public.societies.letterhead_storage_path IS 'Path in society-documents bucket for the society letterhead asset';
COMMENT ON COLUMN public.societies.letterhead_left_mm IS 'Safe content left margin (mm) for letterhead reports';
COMMENT ON COLUMN public.societies.letterhead_right_mm IS 'Safe content right margin (mm) for letterhead reports';
COMMENT ON COLUMN public.societies.default_report_format IS 'Default PDF style: letterhead (official) or plain';
COMMENT ON COLUMN public.societies.letterhead_mode IS 'auto=logo+name band fallback; image=uploaded letterhead as full-page background; stationery=blank for physical pre-printed paper';
COMMENT ON COLUMN public.societies.letterhead_top_mm IS 'Header / contentTop reserve (mm) — content must stay below society header and date area';
COMMENT ON COLUMN public.societies.letterhead_bottom_mm IS 'Footer reserve (mm) — content must stay above letterhead footer';
