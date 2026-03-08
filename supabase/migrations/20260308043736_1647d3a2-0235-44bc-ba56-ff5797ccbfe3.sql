-- Resident users table (phone + password login)
CREATE TABLE public.resident_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL UNIQUE,
  password text NOT NULL,
  name text NOT NULL,
  flat_id uuid REFERENCES public.flats(id) ON DELETE CASCADE NOT NULL,
  flat_number text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Approval requests (guard asks resident to approve/reject visitor)
CREATE TABLE public.approval_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_name text NOT NULL,
  visitor_phone text,
  flat_id uuid REFERENCES public.flats(id) NOT NULL,
  flat_number text NOT NULL,
  guard_id text NOT NULL,
  guard_name text NOT NULL,
  purpose text,
  visitor_photo text,
  status text DEFAULT 'pending' NOT NULL,
  responded_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Visitor passes (OTP-based pre-approval)
CREATE TABLE public.visitor_passes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  otp_code text NOT NULL,
  flat_id uuid REFERENCES public.flats(id) NOT NULL,
  flat_number text NOT NULL,
  created_by_type text NOT NULL,
  created_by_id text NOT NULL,
  created_by_name text NOT NULL,
  guest_name text,
  guest_phone text,
  valid_date date NOT NULL,
  time_slot_start time,
  time_slot_end time,
  status text DEFAULT 'active' NOT NULL,
  used_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.resident_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitor_passes ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "All can read resident_users" ON public.resident_users FOR SELECT USING (true);
CREATE POLICY "All can insert resident_users" ON public.resident_users FOR INSERT WITH CHECK (true);

CREATE POLICY "All can read approval_requests" ON public.approval_requests FOR SELECT USING (true);
CREATE POLICY "All can insert approval_requests" ON public.approval_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "All can update approval_requests" ON public.approval_requests FOR UPDATE USING (true);

CREATE POLICY "All can read visitor_passes" ON public.visitor_passes FOR SELECT USING (true);
CREATE POLICY "All can insert visitor_passes" ON public.visitor_passes FOR INSERT WITH CHECK (true);
CREATE POLICY "All can update visitor_passes" ON public.visitor_passes FOR UPDATE USING (true);

-- Enable realtime for approval requests (for instant notifications)
ALTER PUBLICATION supabase_realtime ADD TABLE public.approval_requests;