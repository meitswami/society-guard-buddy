-- Public onboarding: society signup + PhonePe order + referral + society wallet ledger

-- === Enum-like checks (text + CHECK to keep migrations simple across Supabase) ===

-- Pending signup rows created before payment is confirmed
CREATE TABLE IF NOT EXISTS public.society_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'paid', 'failed', 'cancelled', 'provisioned')),

  -- Society draft data (snapshot)
  society_name text NOT NULL,
  address text,
  city text,
  state text,
  pincode text,
  block_names text[],
  total_floors integer,
  flats_per_floor integer,
  flat_series_start text,
  flat_series_end text,

  contact_person text,
  contact_phone text,
  contact_email text,

  referral_code_used text,

  -- Pricing snapshot (so price can change later without affecting history)
  base_price_inr integer NOT NULL DEFAULT 8500,
  discount_percent integer NOT NULL DEFAULT 0,
  final_price_inr integer NOT NULL DEFAULT 8500,

  notes text
);

CREATE INDEX IF NOT EXISTS society_signups_status_idx ON public.society_signups (status, created_at DESC);
CREATE INDEX IF NOT EXISTS society_signups_phone_idx ON public.society_signups (contact_phone);

-- One order per signup (can be extended to retries later)
CREATE TABLE IF NOT EXISTS public.society_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  signup_id uuid NOT NULL REFERENCES public.society_signups(id) ON DELETE CASCADE,

  provider text NOT NULL DEFAULT 'phonepe',
  amount_inr integer NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  status text NOT NULL DEFAULT 'created'
    CHECK (status IN ('created', 'redirected', 'success', 'failed', 'cancelled')),

  merchant_transaction_id text NOT NULL UNIQUE,
  phonepe_transaction_id text,

  redirect_url text,
  callback_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  callback_verified boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS society_orders_signup_idx ON public.society_orders (signup_id);
CREATE INDEX IF NOT EXISTS society_orders_status_idx ON public.society_orders (status, created_at DESC);

-- Society wallet ledger (society-level balance events, redeemable later)
CREATE TABLE IF NOT EXISTS public.society_wallet_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  entry_type text NOT NULL CHECK (entry_type IN ('credit', 'debit')),
  amount_inr integer NOT NULL CHECK (amount_inr > 0),
  source_order_id uuid REFERENCES public.society_orders(id) ON DELETE SET NULL,
  notes text
);

CREATE INDEX IF NOT EXISTS society_wallet_ledger_society_idx ON public.society_wallet_ledger (society_id, created_at DESC);

-- Referral codes per society
ALTER TABLE public.societies
  ADD COLUMN IF NOT EXISTS referral_code text;

CREATE UNIQUE INDEX IF NOT EXISTS societies_referral_code_uidx
  ON public.societies (lower(trim(referral_code)))
  WHERE referral_code IS NOT NULL AND length(trim(referral_code)) > 0;

-- Referral reward record to enforce idempotency (one per order)
CREATE TABLE IF NOT EXISTS public.society_referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  order_id uuid NOT NULL UNIQUE REFERENCES public.society_orders(id) ON DELETE CASCADE,
  referrer_society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  referred_society_id uuid REFERENCES public.societies(id) ON DELETE SET NULL,
  referral_code_used text NOT NULL,
  reward_percent integer NOT NULL DEFAULT 10 CHECK (reward_percent >= 0 AND reward_percent <= 100),
  referrer_reward_inr integer NOT NULL DEFAULT 0,
  referred_reward_inr integer NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS society_referrals_referrer_idx ON public.society_referrals (referrer_society_id, created_at DESC);

-- === RLS ===
ALTER TABLE public.society_signups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.society_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.society_wallet_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.society_referrals ENABLE ROW LEVEL SECURITY;

-- IMPORTANT: For onboarding, we do NOT allow direct anon inserts; edge functions use service role.
-- (Postgres on Supabase does not support CREATE POLICY IF NOT EXISTS; use drop + create.)
DROP POLICY IF EXISTS "Society signups readable by all (limited use)" ON public.society_signups;
CREATE POLICY "Society signups readable by all (limited use)" ON public.society_signups
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "Society orders readable by all (limited use)" ON public.society_orders;
CREATE POLICY "Society orders readable by all (limited use)" ON public.society_orders
  FOR SELECT USING (true);

-- Lock down writes from client (service-role bypasses RLS anyway)
DROP POLICY IF EXISTS "Society signups no client writes" ON public.society_signups;
CREATE POLICY "Society signups no client writes" ON public.society_signups
  FOR ALL USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS "Society orders no client writes" ON public.society_orders;
CREATE POLICY "Society orders no client writes" ON public.society_orders
  FOR ALL USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS "Society wallet ledger no client writes" ON public.society_wallet_ledger;
CREATE POLICY "Society wallet ledger no client writes" ON public.society_wallet_ledger
  FOR ALL USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS "Society referrals no client writes" ON public.society_referrals;
CREATE POLICY "Society referrals no client writes" ON public.society_referrals
  FOR ALL USING (false) WITH CHECK (false);

