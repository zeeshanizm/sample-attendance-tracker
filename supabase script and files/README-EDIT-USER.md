# Local test — edit users, email and account status

This package is based on your uploaded Attendance-Tracker-Test(1).zip.

## Changed files
- index.html: added Status column and administrator Edit User dialog.
- app.js: renders active/inactive state and calls the secure function to save edits.
- supabase/functions/admin-users/index.ts: supports `update-user` and reports active state in `list`.

## Setup
1. Back up your local test folder. Extract this ZIP and keep the existing TEST config.js; do not use production credentials.
2. In the TEST Supabase project, replace the code in Edge Functions > admin-users with the included index.ts, then deploy.
3. Serve the extracted website locally (e.g. `py -m http.server 5500`).
4. Sign in as admin, open Users, and use Edit user to change email or Active/Inactive status.
5. Test with a non-admin test account. No database migration is required for this change.

## Important behavior
- Email is changed using the privileged Auth Admin API with email_confirm:true; this bypasses email ownership verification. Use only after independently verifying the new address.
- Inactive is implemented as an Auth ban. It blocks subsequent authentication/refresh but does not necessarily revoke already-issued access tokens immediately. For immediate access revocation, add an active-status check to RLS and the Edge Function or explicitly revoke sessions.
- A signed-in admin cannot deactivate their own account; the only admin cannot be deactivated.
- The role and team selectors remain separate from Edit user and are saved using Save role.
- This package has not been integration-tested against Supabase. Do not deploy to production until verified.
