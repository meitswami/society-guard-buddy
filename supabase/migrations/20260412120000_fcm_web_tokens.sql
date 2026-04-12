-- FCM web push tokens (Vite web app). Server sends via FCM HTTP v1 using service account secret.
CREATE TABLE public.fcm_web_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token text NOT NULL UNIQUE,
  user_type text NOT NULL CHECK (user_type IN ('admin', 'guard', 'resident')),
  app_user_id text NOT NULL,
  flat_number text,
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX fcm_web_tokens_society_id_idx ON public.fcm_web_tokens (society_id);
CREATE INDEX fcm_web_tokens_flat_number_idx ON public.fcm_web_tokens (flat_number);
CREATE INDEX fcm_web_tokens_user_idx ON public.fcm_web_tokens (user_type, app_user_id);

ALTER TABLE public.fcm_web_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fcm_web_tokens readable by all" ON public.fcm_web_tokens FOR SELECT USING (true);
CREATE POLICY "fcm_web_tokens insertable by all" ON public.fcm_web_tokens FOR INSERT WITH CHECK (true);
CREATE POLICY "fcm_web_tokens updatable by all" ON public.fcm_web_tokens FOR UPDATE USING (true);
CREATE POLICY "fcm_web_tokens deletable by all" ON public.fcm_web_tokens FOR DELETE USING (true);

CREATE TRIGGER fcm_web_tokens_updated_at
  BEFORE UPDATE ON public.fcm_web_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
