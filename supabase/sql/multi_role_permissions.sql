-- WorkPulse multi-role permissions.
-- Run after role_scope_permissions.sql.
--
-- profiles.role remains as the legacy/highest role so existing screens and
-- policies continue to work while profile_roles stores the real capabilities.

create table if not exists public.profile_roles (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('employee', 'supervisor', 'hr', 'admin')),
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (profile_id, role)
);

drop trigger if exists set_profile_roles_updated_at on public.profile_roles;
create trigger set_profile_roles_updated_at
before update on public.profile_roles
for each row execute function public.set_updated_at();

alter table public.profile_roles enable row level security;

insert into public.profile_roles (profile_id, role)
select id, 'employee'
from public.profiles
on conflict do nothing;

insert into public.profile_roles (profile_id, role)
select id, role
from public.profiles
where role in ('supervisor', 'hr', 'admin')
on conflict do nothing;

create or replace function public.workpulse_highest_role(p_roles text[])
returns text
language sql
immutable
as $$
  select case
    when 'admin' = any(coalesce(p_roles, array[]::text[])) then 'admin'
    when 'hr' = any(coalesce(p_roles, array[]::text[])) then 'hr'
    when 'supervisor' = any(coalesce(p_roles, array[]::text[])) then 'supervisor'
    else 'employee'
  end
$$;

create or replace function public.profile_effective_roles(p_profile_id uuid)
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select array_agg(distinct role order by role)
      from public.profile_roles
      where profile_id = p_profile_id
    ),
    (
      select array['employee', role]::text[]
      from public.profiles
      where id = p_profile_id
    ),
    array['employee']::text[]
  )
$$;

create or replace function public.current_user_roles()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select public.profile_effective_roles(auth.uid())
$$;

create or replace function public.current_user_has_role(p_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_role = any(public.current_user_roles())
$$;

create or replace function public.current_user_has_any_role(p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from unnest(coalesce(p_roles, array[]::text[])) requested(role)
    where requested.role = any(public.current_user_roles())
  )
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select public.workpulse_highest_role(public.current_user_roles())
$$;

grant execute on function public.profile_effective_roles(uuid) to authenticated;
grant execute on function public.current_user_roles() to authenticated;
grant execute on function public.current_user_has_role(text) to authenticated;
grant execute on function public.current_user_has_any_role(text[]) to authenticated;
grant execute on function public.current_user_role() to authenticated;

drop policy if exists "profile_roles_select_related" on public.profile_roles;
create policy "profile_roles_select_related"
on public.profile_roles
for select
to authenticated
using (
  profile_id = auth.uid()
  or public.current_user_has_any_role(array['supervisor', 'hr', 'admin'])
);

drop policy if exists "profile_roles_insert_admin" on public.profile_roles;
create policy "profile_roles_insert_admin"
on public.profile_roles
for insert
to authenticated
with check (public.current_user_has_role('admin'));

drop policy if exists "profile_roles_update_admin" on public.profile_roles;
create policy "profile_roles_update_admin"
on public.profile_roles
for update
to authenticated
using (public.current_user_has_role('admin'))
with check (public.current_user_has_role('admin'));

drop policy if exists "profile_roles_delete_admin" on public.profile_roles;
create policy "profile_roles_delete_admin"
on public.profile_roles
for delete
to authenticated
using (public.current_user_has_role('admin'));

grant select, insert, update, delete on public.profile_roles to authenticated;

create or replace function public.can_manage_employee(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.current_user_has_any_role(array['hr', 'admin']) then true
    when public.current_user_has_role('supervisor') then exists (
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

-- Re-apply scoped visibility policies so this migration is safe to run even
-- when older role migrations were applied in a different order.
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

drop policy if exists "leave_select_reviewer" on public.leave_requests;
create policy "leave_select_reviewer"
on public.leave_requests
for select
to authenticated
using (public.can_manage_employee(user_id));

drop policy if exists "correction_select_reviewer"
on public.correction_requests;
create policy "correction_select_reviewer"
on public.correction_requests
for select
to authenticated
using (public.can_manage_employee(user_id));

drop function if exists public.update_employee_profile(
  uuid,
  text,
  text,
  text,
  uuid,
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
  p_roles text[],
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
  target_roles text[];
  requested_roles text[];
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

  target_roles := public.profile_effective_roles(p_profile_id);

  select coalesce(array_agg(distinct role), array[]::text[])
  into requested_roles
  from unnest(coalesce(p_roles, array[]::text[])) selected_role(role)
  where selected_role.role in ('employee', 'supervisor', 'hr', 'admin');

  if requested_roles is null or cardinality(requested_roles) = 0 then
    requested_roles := array['employee']::text[];
  end if;

  if not ('employee' = any(requested_roles)) then
    requested_roles := array_append(requested_roles, 'employee');
  end if;

  if caller_role <> 'admin'
     and (
       select array_agg(target_role order by target_role)
       from unnest(target_roles) target_role
     ) is distinct from (
       select array_agg(requested_role order by requested_role)
       from unnest(requested_roles) requested_role
     ) then
    raise exception 'Only administrators can change employee access roles.';
  end if;

  if 'admin' = any(target_roles) and caller_role <> 'admin' then
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
       from public.profiles supervisor
       where supervisor.id = p_supervisor_id
         and supervisor.is_active = true
         and 'supervisor' = any(public.profile_effective_roles(supervisor.id))
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
     and 'admin' = any(target_roles)
     and not ('admin' = any(requested_roles)) then
    raise exception 'You cannot remove your own administrator role.';
  end if;

  if 'supervisor' = any(target_roles)
     and not ('supervisor' = any(requested_roles))
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
    role = case
      when caller_role = 'admin' then public.workpulse_highest_role(requested_roles)
      else target_role
    end,
    is_active = p_is_active,
    updated_at = timezone('utc', now())
  where id = p_profile_id;

  if caller_role = 'admin' then
    delete from public.profile_roles
    where profile_id = p_profile_id
      and not (role = any(requested_roles));

    insert into public.profile_roles (profile_id, role, assigned_by)
    select p_profile_id, requested_role, auth.uid()
    from unnest(requested_roles) requested_role
    on conflict (profile_id, role) do nothing;
  end if;

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
  text[],
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
  text[],
  boolean
) to authenticated;

-- Refresh legacy primary roles from profile_roles after the backfill.
update public.profiles profile
set role = public.workpulse_highest_role(public.profile_effective_roles(profile.id));
