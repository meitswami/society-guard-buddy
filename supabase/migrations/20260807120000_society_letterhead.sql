-- Pre-formatted letterhead for society report PDFs / print
ALTER TABLE public.societies
  ADD COLUMN IF NOT EXISTS letterhead_url text,
  ADD COLUMN IF NOT EXISTS letterhead_mode text NOT NULL DEFAULT 'auto',
  ADD COLUMN IF NOT EXISTS letterhead_top_mm numeric NOT NULL DEFAULT 40,
  ADD COLUMN IF NOT EXISTS letterhead_bottom_mm numeric NOT NULL DEFAULT 18;

ALTER TABLE public.societies
  DROP CONSTRAINT IF EXISTS societies_letterhead_mode_check;

ALTER TABLE public.societies
  ADD CONSTRAINT societies_letterhead_mode_check
  CHECK (letterhead_mode IN ('auto', 'image', 'stationery'));

COMMENT ON COLUMN public.societies.letterhead_url IS 'Uploaded letterhead image (PNG/JPG) for digital report stationery';
COMMENT ON COLUMN public.societies.letterhead_mode IS 'auto=logo+name+address band; image=uploaded letterhead; stationery=blank top for physical pre-printed paper';
