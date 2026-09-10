# WorkPulse Employee Import

This folder builds the first safe employee import package from the two HR spreadsheets.

Run from the Flutter project root:

```powershell
.\tools\employee_import\build_employee_import.ps1
```

Generated files are written to `supabase/imports`:

- `workpulse_employee_import_clean.csv`: active employees with unique usable email and required organisation fields.
- `workpulse_employee_import_needs_resolution.csv`: excluded rows with `resolution_reason`.
- `workpulse_employee_import_summary.txt`: counts and rules applied.

The generated import files are ignored by Git because they contain employee data.

## Supabase Flow

1. Run `supabase/sql/employee_bulk_import.sql` in Supabase SQL Editor.
2. Create/import Auth users for clean employees using their real email addresses.
3. Import `workpulse_employee_import_clean.csv` into `public.employee_import_staging`.
4. Run:

```sql
select * from public.apply_employee_import_staging();
```

The function enriches matching `profiles` records with employee ID, name, department, job title, and active employee role.

Rows in `workpulse_employee_import_needs_resolution.csv` should be fixed outside the app before they are imported.

## Pilot Auth Users

Use `create_pilot_auth_users.ps1` to create a small test group before creating hundreds of Auth users.

Dry run:

```powershell
.\tools\employee_import\create_pilot_auth_users.ps1
```

Execute:

```powershell
$env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key"
.\tools\employee_import\create_pilot_auth_users.ps1 -Execute
```

The service role key is found in Supabase Dashboard under project API settings. Keep it out of Flutter, Git, screenshots, and `env.json`.

After the pilot Auth users are created, run this in Supabase SQL Editor:

```sql
select * from public.apply_employee_import_staging();
```

Temporary pilot credentials are written to `supabase/imports/workpulse_pilot_auth_credentials.csv`, which is ignored by Git.
