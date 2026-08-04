-- Managing Committee formation after 3-post election:
-- target size (min 15), and selection types for runners-up / voluntary / executive-proposed.

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS target_committee_size integer NOT NULL DEFAULT 15;

COMMENT ON COLUMN public.polls.target_committee_size IS
  'Society target Managing Committee size (default 15). Formation requires at least 7 members.';

ALTER TABLE public.committee_members DROP CONSTRAINT IF EXISTS committee_members_selection_type_check;

ALTER TABLE public.committee_members
  ADD CONSTRAINT committee_members_selection_type_check
    CHECK (
      selection_type IS NULL
      OR selection_type = ANY (
        ARRAY[
          'elected'::text,
          'nominated'::text,
          'runner_up'::text,
          'voluntary'::text,
          'executive_proposed'::text
        ]
      )
    );

COMMENT ON COLUMN public.committee_members.selection_type IS
  'elected | nominated | runner_up (2nd/3rd from P/S/T poll) | voluntary | executive_proposed.';
