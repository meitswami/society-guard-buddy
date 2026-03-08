
CREATE TABLE public.maintenance_charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  frequency text NOT NULL DEFAULT 'monthly',
  due_day integer NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text
);
CREATE TABLE public.maintenance_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  charge_id uuid REFERENCES public.maintenance_charges(id) ON DELETE CASCADE,
  flat_id uuid REFERENCES public.flats(id) ON DELETE CASCADE,
  flat_number text NOT NULL,
  resident_name text,
  amount numeric NOT NULL,
  payment_method text NOT NULL DEFAULT 'cash',
  payment_status text NOT NULL DEFAULT 'pending',
  payment_date timestamptz,
  due_date date NOT NULL,
  transaction_id text,
  screenshot_url text,
  verified_by text,
  verified_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.donation_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  target_amount numeric DEFAULT 0,
  collected_amount numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'active',
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  end_date date
);
CREATE TABLE public.donation_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid REFERENCES public.donation_campaigns(id) ON DELETE CASCADE,
  flat_id uuid REFERENCES public.flats(id) ON DELETE CASCADE,
  flat_number text NOT NULL,
  resident_name text,
  amount numeric NOT NULL,
  payment_method text NOT NULL DEFAULT 'cash',
  transaction_id text,
  screenshot_url text,
  verified_by text,
  verified_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  event_date date NOT NULL,
  event_time time,
  location text,
  contribution_amount numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'upcoming',
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.event_rsvps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
  flat_id uuid REFERENCES public.flats(id) ON DELETE CASCADE,
  flat_number text NOT NULL,
  resident_name text,
  status text NOT NULL DEFAULT 'attending',
  members_count integer DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.event_contributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
  flat_id uuid REFERENCES public.flats(id) ON DELETE CASCADE,
  flat_number text NOT NULL,
  resident_name text,
  amount numeric NOT NULL,
  payment_method text NOT NULL DEFAULT 'cash',
  transaction_id text,
  screenshot_url text,
  verified_by text,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.polls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  question text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  allow_multiple boolean NOT NULL DEFAULT false,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  end_date timestamptz
);
CREATE TABLE public.poll_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid REFERENCES public.polls(id) ON DELETE CASCADE,
  option_text text NOT NULL,
  votes_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.poll_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid REFERENCES public.polls(id) ON DELETE CASCADE,
  option_id uuid REFERENCES public.poll_options(id) ON DELETE CASCADE,
  voter_id text NOT NULL,
  voter_type text NOT NULL DEFAULT 'resident',
  flat_number text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(poll_id, voter_id)
);
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'general',
  target_type text NOT NULL DEFAULT 'all',
  target_id text,
  is_read boolean NOT NULL DEFAULT false,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.expense_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid REFERENCES public.expense_groups(id) ON DELETE CASCADE,
  title text NOT NULL,
  total_amount numeric NOT NULL,
  paid_by_flat text NOT NULL,
  paid_by_name text,
  split_type text NOT NULL DEFAULT 'equal',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.expense_splits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid REFERENCES public.expenses(id) ON DELETE CASCADE,
  flat_number text NOT NULL,
  resident_name text,
  amount numeric NOT NULL,
  is_settled boolean NOT NULL DEFAULT false,
  settled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.parking_spaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES public.societies(id) ON DELETE CASCADE,
  space_number text NOT NULL,
  space_type text NOT NULL DEFAULT 'car',
  floor_level text,
  is_allocated boolean NOT NULL DEFAULT false,
  allocated_flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL,
  allocated_flat_number text,
  allocated_vehicle_number text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.password_reset_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_type text NOT NULL,
  user_id uuid NOT NULL,
  email text NOT NULL,
  token text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.maintenance_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donation_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donation_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All access maintenance_charges" ON public.maintenance_charges FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access maintenance_payments" ON public.maintenance_payments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access donation_campaigns" ON public.donation_campaigns FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access donation_payments" ON public.donation_payments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access events" ON public.events FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access event_rsvps" ON public.event_rsvps FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access event_contributions" ON public.event_contributions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access polls" ON public.polls FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access poll_options" ON public.poll_options FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access poll_votes" ON public.poll_votes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access notifications" ON public.notifications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access expense_groups" ON public.expense_groups FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access expenses" ON public.expenses FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access expense_splits" ON public.expense_splits FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access parking_spaces" ON public.parking_spaces FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access password_reset_tokens" ON public.password_reset_tokens FOR ALL USING (true) WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
