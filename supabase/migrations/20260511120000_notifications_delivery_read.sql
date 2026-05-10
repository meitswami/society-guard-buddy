-- Per-recipient finance / broadcast notifications: group rows, and capture when a resident opened the alert.

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS delivery_batch_id uuid;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS read_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_notifications_delivery_batch_id
  ON public.notifications (delivery_batch_id)
  WHERE delivery_batch_id IS NOT NULL;

COMMENT ON COLUMN public.notifications.delivery_batch_id IS 'Same UUID on each copy when admin sends individualized notifications (read tracking).';
COMMENT ON COLUMN public.notifications.read_at IS 'When the recipient first marked the notification read (in-app).';
