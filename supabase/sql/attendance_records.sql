-- WorkPulse development reset + bootstrap script.
-- Safe to use only while the project is still in early setup.

drop trigger if exists on_auth_user_created on auth.users;

drop table if exists public.correction_requests cascade;
drop table if exists public.leave_requests cascade;
drop table if exists public.attendance_records cascade;
drop table if exists public.profiles cascade;

drop function if exists public.handle_new_user();
drop function if exists public.set_updated_at();
drop function if exists public.current_user_role();

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  employee_id text unique not null,
  full_name text not null,
  email text unique not null,
  role text not null default 'employee' check (
    role in ('employee', 'supervisor', 'hr', 'admin')
  ),
  department text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  employee_id text not null,
  work_date date not null,
  clock_in timestamptz,
  clock_out timestamptz,
  clock_in_comment text,
  clock_out_comment text,
  clock_in_lat double precision,
  clock_in_lng double precision,
  clock_in_accuracy_m double precision,
  clock_in_inside_geofence boolean,
  clock_out_lat double precision,
  clock_out_lng double precision,
  clock_out_accuracy_m double precision,
  clock_out_inside_geofence boolean,
  status text not null check (
    status in (
      'on_duty',
      'completed',
      'missed_punch',
      'absent',
      'on_leave',
      'leave_pending',
      'correction_pending'
    )
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, work_date)
);

create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  leave_type text not null check (leave_type in ('annual', 'sick', 'other')),
  start_date date not null,
  end_date date not null,
  duration_days integer not null check (duration_days >= 1),
  reason text,
  status text not null check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  reviewer_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.correction_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  attendance_record_id uuid references public.attendance_records(id) on delete set null,
  work_date date not null,
  correction_type text not null check (
    correction_type in ('clock_in', 'clock_out', 'both')
  ),
  corrected_clock_in timestamptz,
  corrected_clock_out timestamptz,
  reason text not null,
  status text not null check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  reviewer_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger set_attendance_records_updated_at
before update on public.attendance_records
for each row execute function public.set_updated_at();

create trigger set_leave_requests_updated_at
before update on public.leave_requests
for each row execute function public.set_updated_at();

create trigger set_correction_requests_updated_at
before update on public.correction_requests
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    employee_id,
    full_name,
    email,
    role
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'employee_id',
      'EMP-' || substr(new.id::text, 1, 8)
    ),
    coalesce(new.raw_user_meta_data ->> 'full_name', 'New User'),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'role', 'employee')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.profiles
  where id = auth.uid()
$$;

grant execute on function public.current_user_role() to authenticated;

insert into public.profiles (
  id,
  employee_id,
  full_name,
  email,
  role
)
select
  users.id,
  coalesce(
    users.raw_user_meta_data ->> 'employee_id',
    'EMP-' || substr(users.id::text, 1, 8)
  ),
  coalesce(users.raw_user_meta_data ->> 'full_name', 'New User'),
  users.email,
  coalesce(users.raw_user_meta_data ->> 'role', 'employee')
from auth.users as users
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.attendance_records enable row level security;
alter table public.leave_requests enable row level security;
alter table public.correction_requests enable row level security;

create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

create policy "profiles_select_reviewer"
on public.profiles
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "attendance_select_own"
on public.attendance_records
for select
to authenticated
using (auth.uid() = user_id);

create policy "attendance_select_reviewer"
on public.attendance_records
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

create policy "attendance_insert_own"
on public.attendance_records
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "attendance_update_own"
on public.attendance_records
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "attendance_update_reviewer"
on public.attendance_records
for update
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'))
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

create policy "attendance_delete_generated_own"
on public.attendance_records
for delete
to authenticated
using (
  auth.uid() = user_id
  and clock_in is null
  and clock_out is null
  and status in ('on_leave', 'leave_pending')
);

create policy "leave_select_own"
on public.leave_requests
for select
to authenticated
using (auth.uid() = user_id);

create policy "leave_select_reviewer"
on public.leave_requests
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

create policy "leave_insert_own"
on public.leave_requests
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "leave_update_pending_own"
on public.leave_requests
for update
to authenticated
using (auth.uid() = user_id and status = 'pending')
with check (auth.uid() = user_id and status = 'pending');

create policy "leave_update_reviewer"
on public.leave_requests
for update
to authenticated
using (
  status = 'pending'
  and public.current_user_role() in ('supervisor', 'hr', 'admin')
)
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

create policy "leave_delete_pending_own"
on public.leave_requests
for delete
to authenticated
using (auth.uid() = user_id and status = 'pending');

create policy "correction_select_own"
on public.correction_requests
for select
to authenticated
using (auth.uid() = user_id);

create policy "correction_select_reviewer"
on public.correction_requests
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

create policy "correction_insert_own"
on public.correction_requests
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "correction_update_pending_own"
on public.correction_requests
for update
to authenticated
using (auth.uid() = user_id and status = 'pending')
with check (auth.uid() = user_id and status = 'pending');

create policy "correction_update_reviewer"
on public.correction_requests
for update
to authenticated
using (
  status = 'pending'
  and public.current_user_role() in ('supervisor', 'hr', 'admin')
)
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

create policy "correction_delete_pending_own"
on public.correction_requests
for delete
to authenticated
using (auth.uid() = user_id and status = 'pending');
