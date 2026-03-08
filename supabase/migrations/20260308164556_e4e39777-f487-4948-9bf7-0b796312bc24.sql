
CREATE POLICY "Guards insertable by all" ON public.guards FOR INSERT WITH CHECK (true);
CREATE POLICY "Guards deletable by all" ON public.guards FOR DELETE USING (true);
CREATE POLICY "Guards updatable by all" ON public.guards FOR UPDATE USING (true);
