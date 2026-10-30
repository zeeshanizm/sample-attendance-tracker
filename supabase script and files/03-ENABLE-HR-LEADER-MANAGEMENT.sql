-- Run AFTER 01 and 02 if team RLS was already activated. Safe for existing records.
BEGIN;
CREATE OR REPLACE FUNCTION public.can_manage_employees()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.is_admin() OR EXISTS (
   SELECT 1 FROM public.user_team_roles r JOIN public.teams t ON t.id=r.team_id
   WHERE r.user_id=(select auth.uid()) AND r.role='leader' AND t.name='HR and Admin'
 );
$$;
REVOKE ALL ON FUNCTION public.can_manage_employees() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_employees() TO authenticated;
DROP POLICY IF EXISTS employees_admin_insert ON public.employees;
DROP POLICY IF EXISTS employees_admin_update ON public.employees;
DROP POLICY IF EXISTS employees_admin_delete ON public.employees;
CREATE POLICY employees_admin_insert ON public.employees FOR INSERT TO authenticated WITH CHECK (public.can_manage_employees());
CREATE POLICY employees_admin_update ON public.employees FOR UPDATE TO authenticated USING (public.can_manage_employees()) WITH CHECK (public.can_manage_employees());
CREATE POLICY employees_admin_delete ON public.employees FOR DELETE TO authenticated USING (public.can_manage_employees());
DROP POLICY IF EXISTS exclusions_admin_insert ON public.employee_exclusions;
DROP POLICY IF EXISTS exclusions_admin_update ON public.employee_exclusions;
DROP POLICY IF EXISTS exclusions_admin_delete ON public.employee_exclusions;
CREATE POLICY exclusions_admin_insert ON public.employee_exclusions FOR INSERT TO authenticated WITH CHECK (public.can_manage_employees());
CREATE POLICY exclusions_admin_update ON public.employee_exclusions FOR UPDATE TO authenticated USING (public.can_manage_employees()) WITH CHECK (public.can_manage_employees());
CREATE POLICY exclusions_admin_delete ON public.employee_exclusions FOR DELETE TO authenticated USING (public.can_manage_employees());
COMMIT;
