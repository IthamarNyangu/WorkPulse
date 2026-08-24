-- WorkPulse employee bulk import staging.
-- Run this in Supabase SQL Editor before importing
-- supabase/imports/workpulse_employee_import_clean.csv into
-- public.employee_import_staging.

create table if not exists public.employee_import_staging (
  employee_id text primary key,
  full_name text not null,
  email text not null,
  role text not null default 'employee',
  department text not null,
  job_title text not null,
  province text not null,
  district text not null,
  facility text not null,
  schedule_code text not null default 'MWF_STANDARD',
  is_active boolean not null default true,
  imported_at timestamptz not null default timezone('utc', now())
);

alter table public.employee_import_staging enable row level security;

drop policy if exists "employee_import_staging_admin_only"
on public.employee_import_staging;
create policy "employee_import_staging_admin_only"
on public.employee_import_staging
for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

grant select, insert, update, delete
on public.employee_import_staging
to authenticated;

create unique index if not exists employee_import_staging_email_lower_unique
on public.employee_import_staging (lower(trim(email)));

create or replace function public.apply_employee_import_staging()
returns table (
  matched_auth_users integer,
  updated_profiles integer,
  unmatched_email_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
  matched_count integer;
  updated_count integer;
  unmatched_count integer;
begin
  caller_role := public.current_user_role();

  if caller_role <> 'admin' then
    raise exception 'Only administrators can apply employee imports.';
  end if;

  if exists (
    select 1
    from public.employee_import_staging
    where role <> 'employee'
      or is_active is distinct from true
      or schedule_code <> 'MWF_STANDARD'
      or trim(employee_id) !~ '^[A-Za-z0-9][A-Za-z0-9._/-]{1,39}$'
      or trim(email) !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
      or nullif(trim(full_name), '') is null
      or nullif(trim(department), '') is null
      or nullif(trim(job_title), '') is null
      or nullif(trim(province), '') is null
      or nullif(trim(district), '') is null
      or nullif(trim(facility), '') is null
  ) then
    raise exception 'Import staging contains invalid rows. Fix the CSV and re-import.';
  end if;

  if exists (
    select lower(trim(email))
    from public.employee_import_staging
    group by lower(trim(email))
    having count(*) > 1
  ) then
    raise exception 'Import staging contains duplicate emails.';
  end if;

  insert into public.departments (name, created_by)
  select distinct on (lower(trim(department)))
    trim(department),
    auth.uid()
  from public.employee_import_staging
  order by lower(trim(department)), trim(department)
  on conflict do nothing;

  with matched as (
    select
      profile.id as profile_id,
      import.employee_id,
      import.full_name,
      import.email,
      import.job_title,
      import.department,
      department.id as department_id
    from public.employee_import_staging import
    join public.profiles profile
      on lower(trim(profile.email)) = lower(trim(import.email))
    left join public.departments department
      on lower(trim(department.name)) = lower(trim(import.department))
  ),
  updated as (
    update public.profiles profile
    set
      employee_id = matched.employee_id,
      full_name = matched.full_name,
      role = 'employee',
      department = matched.department,
      department_id = matched.department_id,
      job_title = matched.job_title,
      is_active = true,
      updated_at = timezone('utc', now())
    from matched
    where profile.id = matched.profile_id
    returning profile.id
  )
  select count(*) into updated_count
  from updated;

  select count(*)
  into matched_count
  from public.employee_import_staging import
  join public.profiles profile
    on lower(trim(profile.email)) = lower(trim(import.email));

  select count(*)
  into unmatched_count
  from public.employee_import_staging import
  where not exists (
    select 1
    from public.profiles profile
    where lower(trim(profile.email)) = lower(trim(import.email))
  );

  return query select matched_count, updated_count, unmatched_count;
end;
$$;

revoke all on function public.apply_employee_import_staging()
from public;

grant execute on function public.apply_employee_import_staging()
to authenticated;
