-- Enable Finance admin tab for all society roles (committee + custom) unless already true.
-- Matches app default: finance is a core society function most admins need.

UPDATE public.society_roles
SET permissions = jsonb_set(COALESCE(permissions, '{}'::jsonb), '{finance}', 'true'::jsonb, true)
WHERE COALESCE(permissions->>'finance', '') IS DISTINCT FROM 'true';
