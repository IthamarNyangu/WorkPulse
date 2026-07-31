-- WorkPulse role boundaries and supervisor reporting-line migration.
-- Run once after employee_management.sql.

create table if not exists public.employee_supervisor_assignments (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  supervisor_id uuid not null references public.profiles(id) on delete cascade,
  is_primary boolean not null default true,
  is_active boolean not null default true,
  effective_from date not null default current_date,
  effective_to date,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (employee_id <> supervisor_id),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index if not exists employee_one_active_primary_supervisor
on public.employee_supervisor_assignments (employee_id)
where is_active = true and is_primary = true;

create index if not exists employee_supervisor_active_supervisor_idx
on public.employee_supervisor_assignments (supervisor_id, is_active);

drop trigger if exists set_employee_supervisor_assignments_updated_at
on public.employee_supervisor_assignments;

create trigger set_employee_supervisor_assignments_updated_at
before update on public.employee_supervisor_assignments
for each row execute function public.set_updated_at();

alter table public.employee_supervisor_assignments enable row level security;

create or replace function public.can_manage_employee(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.current_user_role() in ('hr', 'admin') then true
    when public.current_user_role() = 'supervisor' then exists (
      select 1
      from public.employee_supervisor_assignments assignment
      where assignment.employee_id = target_user_id
        and assignment.supervisor_id = auth.uid()
        and assignment.is_active = true
        and assignment.is_primary = true
        and assignment.effective_from <= current_date
        and (
          assignment.effective_to is null
          or assignment.effective_to >= current_date
        )
    )
    else false
  end
$$;

grant execute on function public.can_manage_employee(uuid) to authenticated;

drop policy if exists "employee_assignments_select_related"
on public.employee_supervisor_assignments;
create policy "employee_assignments_select_related"
on public.employee_supervisor_assignments
for select
to authenticated
using (
  employee_id = auth.uid()
  or supervisor_id = auth.uid()
  or public.current_user_role() in ('hr', 'admin')
);

drop policy if exists "employee_assignments_insert_org_manager"
on public.employee_supervisor_assignments;
create policy "employee_assignments_insert_org_manager"
on public.employee_supervisor_assignments
for insert
to authenticated
with check (public.current_user_role() in ('hr', 'admin'));

drop policy if exists "employee_assignments_update_org_manager"
on public.employee_supervisor_assignments;
create policy "employee_assignments_update_org_manager"
on public.employee_supervisor_assignments
for update
to authenticated
using (public.current_user_role() in ('hr', 'admin'))
with check (public.current_user_role() in ('hr', 'admin'));

drop policy if exists "employee_assignments_delete_org_manager"
on public.employee_supervisor_assignments;
create policy "employee_assignments_delete_org_manager"
on public.employee_supervisor_assignments
for delete
to authenticated
using (public.current_user_role() in ('hr', 'admin'));

grant select, insert, update, delete
on public.employee_supervisor_assignments
to authenticated;

-- Replace broad reviewer policies with organisation-wide HR/Admin access and
-- direct-report-only supervisor access.
drop policy if exists "profiles_select_reviewer" on public.profiles;
create policy "profiles_select_reviewer"
on public.profiles
for select
to authenticated
using (public.can_manage_employee(id));

drop policy if exists "attendance_select_reviewer"
on public.attendance_records;
create policy "attendance_select_reviewer"
on public.attendance_records
for select
to authenticated
using (public.can_manage_employee(user_id));

drop policy if exists "attendance_update_reviewer"
on public.attendance_records;
create policy "attendance_update_reviewer"
on public.attendance_records
for update
to authenticated
using (public.can_manage_employee(user_id))
with check (public.can_manage_employee(user_id));

drop policy if exists "leave_select_reviewer" on public.leave_requests;
create policy "leave_select_reviewer"
on public.leave_requests
for select
to authenticated
using (public.can_manage_employee(user_id));

drop policy if exists "leave_update_reviewer" on public.leave_requests;
create policy "leave_update_reviewer"
on public.leave_requests
for update
to authenticated
using (
  status = 'pending'
  and public.can_manage_employee(user_id)
)
with check (public.can_manage_employee(user_id));

drop policy if exists "correction_select_reviewer"
on public.correction_requests;
create policy "correction_select_reviewer"
on public.correction_requests
for select
to authenticated
using (public.can_manage_employee(user_id));

drop policy if exists "correction_update_reviewer"
on public.correction_requests;
create policy "correction_update_reviewer"
on public.correction_requests
for update
to authenticated
using (
  status = 'pending'
  and public.can_manage_employee(user_id)
)
with check (public.can_manage_employee(user_id));

-- All employees may read active offices for clock-in geofence matching.
-- Only HR and Admin may create or modify office locations.
drop policy if exists "office_locations_select_manager"
on public.office_locations;
create policy "office_locations_select_manager"
on public.office_locations
for select
to authenticated
using (public.current_user_role() in ('hr', 'admin'));

drop policy if exists "office_locations_insert_manager"
on public.office_locations;
create policy "office_locations_insert_manager"
on public.office_locations
for insert
to authenticated
with check (public.current_user_role() in ('hr', 'admin'));

drop policy if exists "office_locations_update_manager"
on public.office_locations;
create policy "office_locations_update_manager"
on public.office_locations
for update
to authenticated
using (public.current_user_role() in ('hr', 'admin'))
with check (public.current_user_role() in ('hr', 'admin'));

-- Replace the employee-management RPC. HR manages organisation fields and
-- account status. Only Admin may change a user's role.
drop function if exists public.update_employee_profile(
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  text,
  boolean
);

create or replace function public.update_employee_profile(
  p_profile_id uuid,
  p_employee_id text,
  p_full_name text,
  p_job_title text,
  p_department_id uuid,
  p_usual_office_location_id uuid,
  p_supervisor_id uuid,
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

  if caller_role not in ('hr', 'admin') then
    raise exception 'Only HR and administrators can edit employee profiles.';
  end if;

  select role
  into target_role
  from public.profiles
  where id = p_profile_id;

  if target_role is null then
    raise exception 'Employee profile was not found.';
  end if;

  if caller_role = 'hr' and target_role = 'admin' then
    raise exception 'HR cannot edit administrator profiles.';
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

  if p_supervisor_id = p_profile_id then
    raise exception 'An employee cannot supervise themselves.';
  end if;

  if p_supervisor_id is not null
     and not exists (
       select 1
       from public.profiles
       where id = p_supervisor_id
         and role = 'supervisor'
         and is_active = true
     ) then
    raise exception 'Select an active supervisor.';
  end if;

  if p_supervisor_id is not null
     and exists (
       with recursive supervisor_chain as (
         select
           assignment.employee_id,
           assignment.supervisor_id
         from public.employee_supervisor_assignments assignment
         where assignment.employee_id = p_supervisor_id
           and assignment.is_active = true
           and assignment.is_primary = true

         union all

         select
           assignment.employee_id,
           assignment.supervisor_id
         from public.employee_supervisor_assignments assignment
         join supervisor_chain chain
           on assignment.employee_id = chain.supervisor_id
         where assignment.is_active = true
           and assignment.is_primary = true
       )
       select 1
       from supervisor_chain
       where supervisor_id = p_profile_id
     ) then
    raise exception 'This supervisor assignment would create a reporting cycle.';
  end if;

  if p_profile_id = auth.uid() and not p_is_active then
    raise exception 'You cannot deactivate your own account.';
  end if;

  if p_profile_id = auth.uid()
     and caller_role = 'admin'
     and p_role <> 'admin' then
    raise exception 'You cannot remove your own administrator role.';
  end if;

  if target_role = 'supervisor'
     and (
       (caller_role = 'admin' and p_role <> 'supervisor')
       or not p_is_active
     )
     and exists (
       select 1
       from public.employee_supervisor_assignments
       where supervisor_id = p_profile_id
         and is_active = true
         and is_primary = true
     ) then
    raise exception 'Reassign this supervisor''s direct reports first.';
  end if;

  update public.profiles
  set
    employee_id = trim(p_employee_id),
    full_name = trim(p_full_name),
    job_title = nullif(trim(p_job_title), ''),
    department_id = p_department_id,
    department = resolved_department_name,
    usual_office_location_id = p_usual_office_location_id,
    role = case when caller_role = 'admin' then p_role else target_role end,
    is_active = p_is_active,
    updated_at = timezone('utc', now())
  where id = p_profile_id;

  update public.employee_supervisor_assignments
  set
    is_active = false,
    effective_to = current_date
  where employee_id = p_profile_id
    and is_active = true
    and is_primary = true
    and supervisor_id is distinct from p_supervisor_id;

  if p_supervisor_id is not null
     and not exists (
       select 1
       from public.employee_supervisor_assignments
       where employee_id = p_profile_id
         and supervisor_id = p_supervisor_id
         and is_active = true
         and is_primary = true
     ) then
    insert into public.employee_supervisor_assignments (
      employee_id,
      supervisor_id,
      is_primary,
      is_active,
      effective_from,
      created_by
    )
    values (
      p_profile_id,
      p_supervisor_id,
      true,
      true,
      current_date,
      auth.uid()
    );
  end if;
end;
$$;

revoke all on function public.update_employee_profile(
  uuid,
  text,
  text,
  text,
  uuid,
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
  uuid,
  text,
  boolean
) to authenticated;
