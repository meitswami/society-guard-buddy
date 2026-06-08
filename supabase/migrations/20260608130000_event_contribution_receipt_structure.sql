-- Structured event contribution receipts: flat-wise vs without flat

ALTER TABLE public.event_contributions
  ADD COLUMN IF NOT EXISTS receipt_basis text NOT NULL DEFAULT 'flat',
  ADD COLUMN IF NOT EXISTS batch_id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS batch_label text;

ALTER TABLE public.event_contributions
  ALTER COLUMN flat_number DROP NOT NULL;

COMMENT ON COLUMN public.event_contributions.receipt_basis IS 'flat = per-flat lines; non_flat = single receipt without flat attribution';
COMMENT ON COLUMN public.event_contributions.batch_id IS 'Groups lines from one Save action (flat-wise batches share one batch_id)';
COMMENT ON COLUMN public.event_contributions.batch_label IS 'Label for non_flat receipts (outsider name or collective description)';
