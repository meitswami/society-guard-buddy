-- Optional media attachments (images/videos) on in-app notifications
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS media_items jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.notifications.media_items IS 'JSON array of {url, kind: "image"|"video"}';

-- Threaded discussion per notification (in-app, replaces informal WhatsApp groups for alerts)
CREATE TABLE public.notification_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  author_resident_id uuid REFERENCES public.resident_users(id) ON DELETE SET NULL,
  author_role text NOT NULL DEFAULT 'resident' CHECK (author_role IN ('resident', 'admin')),
  author_name text NOT NULL,
  author_flat_number text,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notification_comments_notification_id ON public.notification_comments(notification_id);
CREATE INDEX idx_notification_comments_created_at ON public.notification_comments(created_at);

ALTER TABLE public.notification_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "All access notification_comments"
  ON public.notification_comments FOR ALL USING (true) WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE public.notification_comments;

-- Public bucket for notification images/videos (same access pattern as guard-documents)
INSERT INTO storage.buckets (id, name, public)
SELECT 'notification-media', 'notification-media', true
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'notification-media');

CREATE POLICY "notification media readable" ON storage.objects FOR SELECT USING (bucket_id = 'notification-media');
CREATE POLICY "notification media insertable" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'notification-media');
CREATE POLICY "notification media updatable" ON storage.objects FOR UPDATE USING (bucket_id = 'notification-media');
CREATE POLICY "notification media deletable" ON storage.objects FOR DELETE USING (bucket_id = 'notification-media');
