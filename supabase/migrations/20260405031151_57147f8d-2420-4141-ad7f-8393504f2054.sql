
CREATE TABLE public.otp_codes (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  phone text NOT NULL,
  otp_code text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  used boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "OTP codes readable by all" ON public.otp_codes FOR SELECT USING (true);
CREATE POLICY "OTP codes insertable by all" ON public.otp_codes FOR INSERT WITH CHECK (true);
CREATE POLICY "OTP codes updatable by all" ON public.otp_codes FOR UPDATE USING (true);
CREATE POLICY "OTP codes deletable by all" ON public.otp_codes FOR DELETE USING (true);

CREATE INDEX idx_otp_codes_phone ON public.otp_codes(phone);
