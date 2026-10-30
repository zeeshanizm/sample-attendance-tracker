# Attendance Tracker — Employee, Team, User directories (TEST ONLY)

## Files and isolation
This package is built on the prior Local User Management edition. Do not upload it to your live GitHub Pages repository and do not execute any SQL against your live Supabase project until independently validated.

Use a **separate Supabase test project**, with a dedicated `config.js` copied from `config.example.js`. Supply only the TEST project URL and publishable/anon key. Never publish a service-role key. Serve the folder locally with `py -m http.server 5500` and visit `http://localhost:5500`.

## Database setup
A new Supabase project must first receive the ORIGINAL attendance schema (tables `admins`, `employees`, `attendance`, `employee_exclusions`, `is_admin()` and password functions where applicable). The original schema is NOT included here; obtain it from your original tracker backup. Next follow `README-LOCAL-TEST.md` for migrations 01, 02, and 04. The 02 team RLS migration requires **every employee to have a team**. Run `05-DIRECTORIES.sql` in the test project to add `designation` to employees, `description` to teams, and team write policies for admins. Note 04 is needed for safe employee renaming and login links.

**Migration order for an existing test project that already has team RLS and user management:** run only `05-DIRECTORIES.sql` and redeploy the updated `supabase/functions/admin-users/index.ts`. **For a fresh test project:** original schema → 01 → assign teams and roles → 02 → 04 → 05. Validate dependencies before execution.

## Edge Function
Deploy the included `supabase/functions/admin-users/index.ts` to the **test** Supabase project under the name `admin-users`. It must receive the standard `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` as server-side environment variables (Supabase normally provides these). Keep JWT authentication enabled; the function also validates the caller token and checks the `admins` table. Configure Auth URL redirects and SMTP for invitation emails. Test email delivery separately.

## Frontend
- **Employees** (admin): list with S.No., employee name, team, leader name, password reset (only if a login is linked), team selector, designation and Edit; Add employee form with name, team, designation and employment dates. Employee rename uses `rename_employee_safely` RPC.
- **Teams** (admin): list with S.No., team, leader, description, member count and Edit; Add team form; assign existing employees with multi-select; choose leader **from an existing employee who already has a linked login**. If no linked login, first create their account under Users, then assign leader.
- **Users** (admin): list with S.No., employee, login email, reset password, role, team and Save; Add new user form offers email invitation or admin-created password. Admin role changes are server-side.

**Important current limitations:** assigning multiple employees or changing team leadership consists of multiple requests, not one database transaction. If a request fails partway, inspect the saved state and correct it. Changing an employee's team changes the scope of their historical attendance under the current name-based schema. Team leader display depends on linked accounts. Password reset uses a temporary password entered in the browser; share it via a secure channel. A team can have multiple `leader` role accounts; this UI does not enforce a single-leader constraint. A normal user cannot see the admin directories.

## Test cases
1. Add a test employee; refresh and confirm they appear in Employees and the attendance register.
2. Rename a test employee with attendance/exclusions and verify historical rows are retained.
3. Create a test team and update its description.
4. Assign an existing employee to that team and verify the team member count.
5. Create a login for the employee with an initial password; log in as that employee.
6. Change that login to Team leader for the employee's team; sign out and back in; verify attendance writes are limited to that team.
7. Invite another test employee; verify the invitation email and password setup.
8. Reset a test account password and verify the new login works.
9. Confirm a non-admin cannot call the admin Edge Function or access admin management screens.
10. Confirm production GitHub Pages and production Supabase remain unchanged.

This package has passed JavaScript syntax validation, but has **not** been end-to-end tested against a live Supabase test project. Review RLS, invitation configuration and name-based foreign keys before any production deployment.
