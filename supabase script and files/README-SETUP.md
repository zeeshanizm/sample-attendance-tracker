# Organization Attendance Tracker — team access

## What's new
- Five teams: HR and Admin, Development Team, Quality Assurance Team, Software Support Team, ACE/ACI Support Team.
- Administrators: edit attendance for every team, manage employee dates/exclusions, assign employees to teams, and view the entire organization.
- Team leaders: edit attendance only for employees assigned to their team; read their own team. The HR and Admin team leader additionally manages employee profiles, exclusions and team assignments across the organization.
- HR viewers: view all organization attendance, but cannot modify it.
- Ordinary users: read-only attendance for their assigned teams.
- A team leader can also be an employee. Assign their employee row to a team, **and** assign their Supabase Auth account the `leader` role.
- Existing logo, password management, joining/leaving dates, exclusions, exports, and paginated attendance loading remain.

## Deployment sequence — IMPORTANT
1. Back up Supabase tables (`employees`, `attendance`, `employee_exclusions`, `admins`) before changing policies.
2. Run `01-TEAM-SETUP.sql` in Supabase SQL Editor. This only adds tables, columns and helper functions; existing access remains unchanged.
3. Assign **every employee** to one of the five teams. Use the Supabase Table Editor (`public.employees`, column `team_id`), or use the new administrator **Team assignments** dialog **after** deploying the frontend. Team IDs are shown in that dialog and can also be found with `SELECT id,name FROM public.teams ORDER BY name;`.
4. Assign roles to all Supabase Auth accounts using the examples below. Admin accounts already listed in `public.admins` do not need a `user_team_roles` row. Every non-admin account needs one or more roles to see data after team RLS activation.
5. Upload `index.html`, `style.css`, `app.js`, `companylogo.png` to your existing GitHub Pages repository. **Keep your current `config.js`**. Commit and refresh the site. Before RLS activation, users may still have the old broader read access; finish activation promptly after checking assignments.
6. Only when employee and user mappings are complete, run `02-ACTIVATE-TEAM-RLS.sql` in Supabase SQL Editor. This enforces permissions at the database level, not just by hiding buttons.
7. Test with separate admin, team leader, HR viewer and ordinary accounts. Confirm a leader cannot write to another team's attendance, including via a direct API request. Test both blank-to-P and P-to-blank.

## Find Auth user IDs and team IDs
```sql
SELECT id, email FROM auth.users ORDER BY email;
SELECT id, name FROM public.teams ORDER BY name;
SELECT name, team_id FROM public.employees ORDER BY name;
```

## Assign a team leader (replace email and team name)
```sql
INSERT INTO public.user_team_roles(user_id, team_id, role)
SELECT u.id, t.id, 'leader'
FROM auth.users u CROSS JOIN public.teams t
WHERE u.email='leader@example.com' AND t.name='Software Support Team'
ON CONFLICT DO NOTHING;
```

## Assign an ordinary read-only team member
```sql
INSERT INTO public.user_team_roles(user_id, team_id, role)
SELECT u.id, t.id, 'member'
FROM auth.users u CROSS JOIN public.teams t
WHERE u.email='employee@example.com' AND t.name='Development Team'
ON CONFLICT DO NOTHING;
```

## Assign HR read-only organization-wide access
```sql
INSERT INTO public.user_team_roles(user_id, team_id, role)
SELECT id, NULL, 'hr_viewer' FROM auth.users WHERE email='hr@example.com'
ON CONFLICT DO NOTHING;
```

## Revoke an old role
```sql
-- Example: remove one user's leader privilege without deleting their Auth account.
DELETE FROM public.user_team_roles
WHERE user_id=(SELECT id FROM auth.users WHERE email='leader@example.com')
AND role='leader';
```

## Important safeguards
- **Do not rerun** the original `schema.sql` or `seed.sql`.
- Do not add a service-role key to GitHub, `app.js`, or `config.js`.
- `01-TEAM-SETUP.sql` is additive. `02-ACTIVATE-TEAM-RLS.sql` deliberately replaces old RLS policies on `employees`, `attendance`, `employee_exclusions` so that a normal user cannot bypass team restrictions by calling Supabase directly.
- Back up and inspect any custom policies on those tables before activating. If you have other integrations that depend on those policies, adjust the migration accordingly.
- Other team leaders can edit attendance only. The HR and Admin team leader can also manage employee records, dates, exclusions and team assignments across teams, but cannot edit other teams’ attendance.
- HR viewers can view all teams but cannot edit.
- If an employee moves teams, existing attendance history follows their employee record and becomes visible to the new team's authorized users. Historical team-at-date attribution is **not** implemented in this version.
- Administrator account access is based on the existing `public.is_admin()` function.
- The frontend uses `user_team_roles` to populate team choices, but the RLS policies enforce access even if a user modifies the frontend.
- This release does not add an admin interface to create or revoke login-user team roles. Use the SQL examples above for that sensitive operation.

## HR and Admin team leader extension
- For a NEW installation, use the updated `01-TEAM-SETUP.sql` and `02-ACTIVATE-TEAM-RLS.sql`. Do not also run `03`.
- If you ALREADY ran the original team setup and activation scripts, run only `03-ENABLE-HR-LEADER-MANAGEMENT.sql` and upload the updated `app.js` and `index.html`.
- Assign the HR leader their login `leader` role for the `HR and Admin` team using the SQL example above, substituting that team name.
- A user with `hr_viewer` only remains read-only; HR management requires the HR and Admin team `leader` role.
- Do not rerun original schema.sql or seed.sql.
