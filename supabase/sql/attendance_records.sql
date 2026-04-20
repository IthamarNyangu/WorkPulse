create extension if not exists pgcrypto;

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  employee_id text not null,
  work_date date not null,
  clock_in_at timestamptz,
  clock_out_at timestamptz,
  comment text,
  status text not null default 'off_duty',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists attendance_records_user_date_idx
on public.attendance_records (user_id, employee_id, work_date);

alter table public.attendance_records enable row level security;

create policy "Users can read own attendance"
on public.attendance_records
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own attendance"
on public.attendance_records
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own attendance"
on public.attendance_records
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.set_attendance_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists attendance_records_set_updated_at
on public.attendance_records;

create trigger attendance_records_set_updated_at
before update on public.attendance_records
for each row
execute function public.set_attendance_updated_at();
