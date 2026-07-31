-- WorkPulse employee and organisation management migration.
-- Run once in Supabase SQL Editor after the existing attendance, approval,
-- and office-location migrations.

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 80),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists departments_name_lower_unique
on public.departments (lower(trim(name)));

alter table public.profiles
add column if not exists department_id uuid,
add column if not exists job_title text,
add column if not exists usual_office_location_id uuid,
add column if not exists is_active boolean not null default true;

do $$
begin
  alter table public.profiles
  add constraint profiles_department_id_fkey
  foreign key (department_id)
  references public.departments(id)
  on delete set null;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table public.profiles
  add constraint profiles_usual_office_location_id_fkey
  foreign key (usual_office_location_id)
  references public.office_locations(id)
  on delete set null;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table public.profiles
  add constraint profiles_job_title_length_check
  check (
    job_title is null
    or char_length(trim(job_title)) between 2 and 120
  );
exception
  when duplicate_object then null;
end $$;

insert into public.departments (name)
select distinct on (lower(trim(profile_department)))
  trim(profile_department)
from (
  select department as profile_department
  from public.profiles
  where nullif(trim(department), '') is not null
) existing_departments
order by lower(trim(profile_department)), trim(profile_department)
on conflict do nothing;

update public.profiles profile
set department_id = department.id
from public.departments department
where profile.department_id is null
  and nullif(trim(profile.department), '') is not null
  and lower(trim(profile.department)) = lower(trim(department.name));

drop trigger if exists set_departments_updated_at on public.departments;
create trigger set_departments_updated_at
before update on public.departments
for each row execute function public.set_updated_at();

alter table public.departments enable row level security;

drop policy if exists "departments_select_active" on public.departments;
create policy "departments_select_active"
on public.departments
for select
to authenticated
using (is_active = true);

drop policy if exists "departments_select_manager" on public.departments;
create policy "departments_select_manager"
on public.departments
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "departments_insert_org_admin" on public.departments;
create policy "departments_insert_org_admin"
on public.departments
for insert
to authenticated
with check (public.current_user_role() in ('hr', 'admin'));

drop policy if exists "departments_update_org_admin" on public.departments;
create policy "departments_update_org_admin"
on public.departments
for update
to authenticated
using (public.current_user_role() in ('hr', 'admin'))
with check (public.current_user_role() in ('hr', 'admin'));

grant select on public.departments to authenticated;
grant insert, update on public.departments to authenticated;

-- Direct profile updates previously allowed employees to change protected
-- organisational fields, including role. All managed edits now use the
-- role-aware function below.
drop policy if exists "profiles_update_own" on public.profiles;
revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;

create or replace function public.update_employee_profile(
  p_profile_id uuid,
  p_employee_id text,
  p_full_name text,
  p_job_title text,
  p_department_id uuid,
  p_usual_office_location_id uuid,
  p_role text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
  target_role text;
  resolved_department_name text;
begin
  caller_role := public.current_user_role();

  if caller_role not in ('supervisor', 'hr', 'admin') then
    raise exception 'You are not authorised to manage employee profiles.';
  end if;

  select role
  into target_role
  from public.profiles
  where id = p_profile_id;

  if target_role is null then
    raise exception 'Employee profile was not found.';
  end if;

  if caller_role = 'supervisor' and target_role in ('hr', 'admin') then
    raise exception 'Supervisors cannot edit HR or administrator profiles.';
  end if;

  if nullif(trim(p_full_name), '') is null
     or char_length(trim(p_full_name)) > 120 then
    raise exception 'Full name must contain between 1 and 120 characters.';
  end if;

  if trim(p_employee_id) !~ '^[A-Za-z0-9][A-Za-z0-9._/-]{1,39}$' then
    raise exception 'Employee ID contains unsupported characters.';
  end if;

  if p_job_title is not null
     and nullif(trim(p_job_title), '') is not null
     and char_length(trim(p_job_title)) not between 2 and 120 then
    raise exception 'Job title must contain between 2 and 120 characters.';
  end if;

  if p_role not in ('employee', 'supervisor', 'hr', 'admin') then
    raise exception 'Unsupported employee role.';
  end if;

  if p_department_id is not null then
    select name
    into resolved_department_name
    from public.departments
    where id = p_department_id
      and is_active = true;

    if resolved_department_name is null then
      raise exception 'Select an active department.';
    end if;
  end if;

  if p_usual_office_location_id is not null
     and not exists (
       select 1
       from public.office_locations
       where id = p_usual_office_location_id
         and is_active = true
     ) then
    raise exception 'Select an active usual office.';
  end if;

  if p_profile_id = auth.uid() and not p_is_active then
    raise exception 'You cannot deactivate your own account.';
  end if;

  update public.profiles
  set
    employee_id = trim(p_employee_id),
    full_name = trim(p_full_name),
    job_title = nullif(trim(p_job_title), ''),
    department_id = p_department_id,
    department = resolved_department_name,
    usual_office_location_id = p_usual_office_location_id,
    role = case
      when caller_role in ('hr', 'admin') then p_role
      else target_role
    end,
    is_active = case
      when caller_role in ('hr', 'admin') then p_is_active
      else is_active
    end,
    updated_at = timezone('utc', now())
  where id = p_profile_id;
end;
$$;

revoke all on function public.update_employee_profile(
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  text,
  boolean
) from public;

grant execute on function public.update_employee_profile(
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  text,
  boolean
) to authenticated;

create index if not exists profiles_department_id_idx
on public.profiles (department_id);

create index if not exists profiles_usual_office_location_id_idx
on public.profiles (usual_office_location_id);

create index if not exists profiles_is_active_idx
on public.profiles (is_active);
