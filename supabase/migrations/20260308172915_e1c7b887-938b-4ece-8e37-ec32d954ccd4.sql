
CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  event_type text NOT NULL,
  user_type text NOT NULL,
  user_id text,
  user_name text,
  ip_address text,
  user_agent text,
  device_info jsonb DEFAULT '{}',
  details jsonb DEFAULT '{}',
  severity text NOT NULL DEFAULT 'info'
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Audit logs insertable by all" ON public.audit_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Audit logs readable by all" ON public.audit_logs FOR SELECT USING (true);
