
-- Allow updating admins (for password change)
CREATE POLICY "Admins updatable by all" ON public.admins FOR UPDATE USING (true);

-- Allow deleting admins (for superadmin management)
CREATE POLICY "Admins deletable by all" ON public.admins FOR DELETE USING (true);

-- Allow inserting admins (for superadmin to create new admins)
CREATE POLICY "Admins insertable by all" ON public.admins FOR INSERT WITH CHECK (true);

-- Allow updating and deleting resident_users (for admin resident management)
CREATE POLICY "Resident users updatable by all" ON public.resident_users FOR UPDATE USING (true);
CREATE POLICY "Resident users deletable by all" ON public.resident_users FOR DELETE USING (true);
