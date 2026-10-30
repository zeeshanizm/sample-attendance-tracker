# Attendance Tracker — local testing / user and role management

## Safety and scope
- **TEST ENVIRONMENT ONLY.** No commands in this package are executed against your Supabase project automatically.
- Keep your live GitHub repository, production `config.js`, production Supabase database, and production Auth users unchanged.
- This package builds on the previous multi-team version; it is not a replacement for your original schema and earlier employment/exclusion migrations.
- Tested: JavaScript syntax and ZIP contents. **Not tested against a live Supabase instance or real SMTP provider.**
- Supabase free plan may restrict the number of active projects. A separate test organization or Supabase CLI/Docker stack is an alternative.

## Files
- `index.html`, `style.css`, `app.js`, `companylogo.png`: website
- `config.example.js`: public test connection settings; copy to `config.js`
- `01-TEAM-SETUP.sql`, `02-ACTIVATE-TEAM-RLS.sql`: inherited team setup scripts
- `04-USER-MANAGEMENT.sql`: employee login linking and atomic rename RPC
- `supabase/functions/admin-users/index.ts`: administrator-verified account management Edge Function

## Prepare a fresh test project
1. Create a separate Supabase test project; do not use production credentials.
2. Run your ORIGINAL `schema.sql` and required prior employment/exclusions migrations in the test project. Do not run `seed.sql` with real employee data; add sample employees.
3. Run `01-TEAM-SETUP.sql` in test project SQL Editor.
4. Run `04-USER-MANAGEMENT.sql` in test project SQL Editor. Before running, review any custom employee foreign keys or triggers.
5. Create a test administrator under Authentication > Users. Add its Auth UUID to `public.admins(user_id)` using the test SQL editor (verify actual admins schema).
6. Assign a team to **every** sample employee; assign at least one sample employee to each of the five teams.
7. Run `02-ACTIVATE-TEAM-RLS.sql` **after** all employees have team assignments. This script replaces existing policies on employee/attendance/exclusion tables in the test project.
8. Deploy `supabase/functions/admin-users/index.ts` as Edge Function `admin-users`. Keep Verify JWT enabled if your project's signing/key mode supports gateway JWT verification; otherwise consult Supabase current docs for the new key model. The function ALWAYS validates the user's token and admin membership itself.
9. The function uses automatically supplied `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` in the hosted Supabase environment. Do not expose service-role keys to the browser or GitHub.
10. For email invitations, configure Auth > URL Configuration and SMTP/email templates for your test project. Add `http://localhost:5500/` as an allowed redirect URL. Invited users should complete the invitation and set a password using Supabase's invite/recovery flow; check that the frontend handles your chosen invite template/redirect.
11. Copy `config.example.js` to `config.js`, replacing placeholders with your TEST project's URL and publishable key.
12. In a terminal in this folder run `py -m http.server 5500` (Windows with Python installed) and visit `http://localhost:5500/`. Alternatively use VS Code Live Server.
13. Sign in with the test admin account. Open **User & role management**. Create an employee login using an invitation or initial password. Set roles and test access with a second browser profile.

## Role rules
- Admin: full organization attendance edits, employee management, user management, password management.
- HR and Admin team leader: employee management, exclusions, team assignments, own-team attendance edits, organization-wide view. Cannot create login accounts or change user roles.
- Other team leader: edit their own team's attendance only.
- HR viewer: organization-wide read only.
- Member/user: assigned team's read-only attendance.
- A leader MUST be linked to an employee assigned to the same team.
- Role changes take effect after sign-out/sign-in or reload; RLS checks permissions server-side.

## Known limitations and safeguards
- A renamed employee is updated across `employees`, `attendance`, `employee_exclusions`, and `employee_login_links`. Review custom foreign keys/triggers before renaming.
- Employee names are still the attendance foreign key; migrating to immutable employee UUIDs is preferable longer-term.
- User provisioning spans Supabase Auth and PostgreSQL, so it is not one atomic transaction; the function attempts to delete a newly created Auth account if role/link setup fails. Verify cleanup if an error occurs.
- Existing login accounts not yet linked to employees appear in the admin user list, but cannot be promoted to team leader until linked; the current interface does not link old accounts. Create fresh test accounts first.
- User role editing changes roles but does not change employee/team assignments. Use Team assignments separately.
- The user-management function is for a test environment and should receive additional production hardening (rate limiting, audit log, least privilege, account lifecycle controls, SMTP/redirect checks, and explicit approval for admin promotions).
- Invitation delivery depends on your SMTP provider and Supabase email configuration.
- A test account with a manually set password is created with email_confirm=true; only use trusted test emails.
- No user deletion interface is provided; deprovisioning requires separate administrator workflow.
- If a team leader is transferred, change both their employee team and their login role/team; the function validates consistency at role assignment time.
- Test the RLS behavior with direct API requests, not only the visibility of frontend controls.

## Test matrix
1. Admin can create user by invitation and manual password.
2. Admin can change normal user to leader and back; linked employee must match team.
3. Admin can rename an employee with existing attendance/exclusions; all records survive.
4. Leader can edit own-team attendance, but not another team's (including direct REST call).
5. HR/Admin leader can manage employees and exclusions but not user roles.
6. HR viewer can view organization but cannot edit.
7. Member cannot edit.
8. Refresh after saving P and verify it persists; check monthly/yearly exports.
9. Verify forgot-password and admin-password reset workflows separately if you deploy `admin-passwords` function from your prior package.

## Deployment to production (later, after independent validation)
Back up production, compare custom schema/policies, stage migration, create user roles, verify admin access, then deploy the tested frontend. NEVER copy the test `config.js` to production.
