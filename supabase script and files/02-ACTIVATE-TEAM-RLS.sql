-- Run ONLY after all employees have team_id and all login users have appropriate role mappings.
-- This replaces existing SELECT and write policies on the 3 tables to enforce team isolation.
-- Back up database first. Existing attendance rows are not deleted.
BEGIN;
DO $$
DECLARE t text; p record;
BEGIN
 IF EXISTS (SELECT 1 FROM public.employees WHERE team_id IS NULL) THEN
   RAISE EXCEPTION 'Some employees are not assigned to a team. Assign them before activating team RLS.';
 END IF;
 FOR t IN SELECT unnest(ARRAY['employees','attendance','employee_exclusions']) LOOP
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
   EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,t);
  END LOOP;
 END LOOP;
END $$;
-- employees: admins and HR/Admin team leader manage; team members/leaders read their own team; HR reads all.
CREATE POLICY employees_team_read ON public.employees FOR SELECT TO authenticated
 USING (public.can_view_team(team_id));
CREATE POLICY employees_admin_insert ON public.employees FOR INSERT TO authenticated
 WITH CHECK (public.can_manage_employees());
CREATE POLICY employees_admin_update ON public.employees FOR UPDATE TO authenticated
 USING (public.can_manage_employees()) WITH CHECK (public.can_manage_employees());
CREATE POLICY employees_admin_delete ON public.employees FOR DELETE TO authenticated
 USING (public.can_manage_employees());
-- attendance: team leader writes only employees currently assigned to their team.
CREATE POLICY attendance_team_read ON public.attendance FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.employees e WHERE e.name=attendance.employee AND public.can_view_team(e.team_id)));
CREATE POLICY attendance_team_insert ON public.attendance FOR INSERT TO authenticated
 WITH CHECK (EXISTS (SELECT 1 FROM public.employees e WHERE e.name=attendance.employee AND public.can_edit_team(e.team_id)));
CREATE POLICY attendance_team_update ON public.attendance FOR UPDATE TO authenticated
 USING (EXISTS (SELECT 1 FROM public.employees e WHERE e.name=attendance.employee AND public.can_edit_team(e.team_id)))
 WITH CHECK (EXISTS (SELECT 1 FROM public.employees e WHERE e.name=attendance.employee AND public.can_edit_team(e.team_id)));
CREATE POLICY attendance_team_delete ON public.attendance FOR DELETE TO authenticated
 USING (EXISTS (SELECT 1 FROM public.employees e WHERE e.name=attendance.employee AND public.can_edit_team(e.team_id)));
-- exclusions: admins and HR/Admin team leader modify exclusions; team users may read those of visible employees.
CREATE POLICY exclusions_team_read ON public.employee_exclusions FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.employees e WHERE e.name=employee_exclusions.employee AND public.can_view_team(e.team_id)));
CREATE POLICY exclusions_admin_insert ON public.employee_exclusions FOR INSERT TO authenticated
 WITH CHECK (public.can_manage_employees());
CREATE POLICY exclusions_admin_update ON public.employee_exclusions FOR UPDATE TO authenticated
 USING (public.can_manage_employees()) WITH CHECK (public.can_manage_employees());
CREATE POLICY exclusions_admin_delete ON public.employee_exclusions FOR DELETE TO authenticated
 USING (public.can_manage_employees());

COMMIT;
