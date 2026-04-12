-- RBAC: per-role JSON permissions for society admin panel; optional slug for seeded templates

ALTER TABLE public.society_roles
  ADD COLUMN IF NOT EXISTS permissions jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS slug text;

CREATE INDEX IF NOT EXISTS society_roles_society_slug_idx ON public.society_roles (society_id, slug);

-- Full access template (Admin)
UPDATE public.society_roles
SET
  slug = COALESCE(slug, 'admin'),
  permissions = '{"residents_rw":true,"guards_rw":true,"geofence_rw":true,"finance":true,"donations":true,"splits":true,"events":true,"polls":true,"notifications":true,"parking":true,"visitor":true,"delivery":true,"vehicle":true,"blacklist":true,"directory":true,"quick":true,"report":true,"logs":true,"audit":true,"settings":true,"password":true,"biometric":true}'::jsonb
WHERE lower(trim(role_name)) = 'admin';

-- Seed standard roles (Treasurer, President, Vice-President, Secretary) for every society if missing
INSERT INTO public.society_roles (society_id, role_name, slug, permissions)
SELECT s.id, x.role_name, x.slug, x.permissions::jsonb
FROM public.societies s
CROSS JOIN (
  VALUES
    (
      'Treasurer',
      'treasurer',
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":true,"donations":true,"splits":true,"events":true,"polls":false,"notifications":true,"parking":false,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":true,"logs":false,"audit":false,"settings":false,"password":true,"biometric":true}'
    ),
    (
      'President',
      'president',
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":false,"donations":false,"splits":false,"events":true,"polls":true,"notifications":true,"parking":true,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":true,"logs":true,"audit":true,"settings":false,"password":true,"biometric":true}'
    ),
    (
      'Vice-President',
      'vice_president',
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":false,"donations":false,"splits":false,"events":true,"polls":true,"notifications":true,"parking":true,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":true,"logs":true,"audit":false,"settings":false,"password":true,"biometric":true}'
    ),
    (
      'Secretary',
      'secretary',
      '{"residents_rw":false,"guards_rw":false,"geofence_rw":false,"finance":false,"donations":false,"splits":false,"events":true,"polls":true,"notifications":true,"parking":false,"visitor":false,"delivery":false,"vehicle":false,"blacklist":false,"directory":true,"quick":false,"report":false,"logs":false,"audit":false,"settings":false,"password":true,"biometric":true}'
    )
) AS x(role_name, slug, permissions)
WHERE NOT EXISTS (
  SELECT 1 FROM public.society_roles r
  WHERE r.society_id = s.id AND r.slug = x.slug
);
