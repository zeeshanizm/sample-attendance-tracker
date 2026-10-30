-- TEST SUPABASE PROJECT ONLY. Apply after 01, 02, and 04 migrations.
BEGIN;
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS designation text;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS description text;
DROP POLICY IF EXISTS teams_admin_insert ON public.teams;
DROP POLICY IF EXISTS teams_admin_update ON public.teams;
CREATE POLICY teams_admin_insert ON public.teams FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY teams_admin_update ON public.teams FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
COMMIT;
