-- TEST PROJECT ONLY. Run after 01-TEAM-SETUP.sql. Requires existing admins and employees.
-- Do not execute in production until independently tested.
BEGIN;
CREATE TABLE IF NOT EXISTS public.employee_login_links (
 employee_name text PRIMARY KEY REFERENCES public.employees(name) ON UPDATE CASCADE ON DELETE CASCADE,
 user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.employee_login_links ENABLE ROW LEVEL SECURITY;
-- Only service-role function can read/write mappings; do not add client policies.

-- Ensure name-based foreign keys can follow employee renames. Only the
-- attendance/exclusions FKs referencing employees are modified.
DO $$
DECLARE c record; definition text;
BEGIN
 FOR c IN
  SELECT con.conname, con.conrelid::regclass AS rel, pg_get_constraintdef(con.oid) AS definition
  FROM pg_constraint con
  WHERE con.contype='f' AND con.confrelid='public.employees'::regclass
    AND con.conrelid IN ('public.attendance'::regclass,'public.employee_exclusions'::regclass)
 LOOP
  definition:=regexp_replace(c.definition,' ON UPDATE (NO ACTION|RESTRICT|CASCADE|SET NULL|SET DEFAULT)','');
  definition:=regexp_replace(definition,' ON DELETE',' ON UPDATE CASCADE ON DELETE');
  IF position('ON UPDATE CASCADE' in definition)=0 THEN definition:=definition||' ON UPDATE CASCADE'; END IF;
  EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I',c.rel,c.conname);
  EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s',c.rel,c.conname,definition);
 END LOOP;
END $$;

-- Atomic employee rename across existing name-keyed tables.
-- Authenticated administrators only. Uses definer privileges after explicit authorization.
CREATE OR REPLACE FUNCTION public.rename_employee_safely(old_name text,new_name text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 IF old_name IS NULL OR new_name IS NULL OR length(btrim(new_name))<1 OR length(new_name)>150 THEN RAISE EXCEPTION 'Invalid name'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.employees WHERE name=old_name) THEN RAISE EXCEPTION 'Employee not found'; END IF;
 IF EXISTS (SELECT 1 FROM public.employees WHERE name=btrim(new_name) AND name<>old_name) THEN RAISE EXCEPTION 'Employee name already exists'; END IF;
 -- Existing foreign keys may be restrictive. Deferring deferrable constraints allows
 -- this transaction to update all name-keyed rows; non-deferrable restrictive FKs
 -- must be migrated to ON UPDATE CASCADE before using this function.
 UPDATE public.employees SET name=btrim(new_name) WHERE name=old_name;
 UPDATE public.attendance SET employee=btrim(new_name) WHERE employee=old_name;
 UPDATE public.employee_exclusions SET employee=btrim(new_name) WHERE employee=old_name;
 UPDATE public.employee_login_links SET employee_name=btrim(new_name) WHERE employee_name=old_name;
END $$;
REVOKE ALL ON FUNCTION public.rename_employee_safely(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rename_employee_safely(text,text) TO authenticated;
COMMIT;
