-- WorkPulse multi-office geofence migration.
-- Run this in Supabase SQL Editor for existing projects.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.office_locations (
  id uuid primary key default gen_random_uuid(),
  office_name text not null,
  province text,
  district text,
  latitude double precision not null,
  longitude double precision not null,
  radius_m double precision not null check (radius_m >= 80 and radius_m <= 500),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.office_locations
add column if not exists district text;

alter table public.office_locations
drop constraint if exists office_locations_radius_m_check;

alter table public.office_locations
add constraint office_locations_radius_m_check
check (radius_m >= 80 and radius_m <= 500);

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

create unique index if not exists office_locations_office_name_key
on public.office_locations (office_name);

drop trigger if exists set_office_locations_updated_at
on public.office_locations;

create trigger set_office_locations_updated_at
before update on public.office_locations
for each row execute function public.set_updated_at();

alter table public.attendance_records
add column if not exists clock_in_verified_office_location_id uuid references public.office_locations(id) on delete set null,
add column if not exists clock_out_verified_office_location_id uuid references public.office_locations(id) on delete set null,
add column if not exists clock_in_nearest_office_location_id uuid references public.office_locations(id) on delete set null,
add column if not exists clock_out_nearest_office_location_id uuid references public.office_locations(id) on delete set null,
add column if not exists clock_in_distance_m double precision,
add column if not exists clock_out_distance_m double precision,
add column if not exists clock_in_geofence_radius_m double precision,
add column if not exists clock_out_geofence_radius_m double precision,
add column if not exists clock_in_location_status text,
add column if not exists clock_out_location_status text;

do $$
begin
  alter table public.attendance_records
  add constraint attendance_clock_in_location_status_check
  check (
    clock_in_location_status is null
    or clock_in_location_status in (
      'inside_office',
      'outside_all_offices',
      'location_unavailable',
      'low_accuracy',
      'no_offices_configured'
    )
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table public.attendance_records
  add constraint attendance_clock_out_location_status_check
  check (
    clock_out_location_status is null
    or clock_out_location_status in (
      'inside_office',
      'outside_all_offices',
      'location_unavailable',
      'low_accuracy',
      'no_offices_configured'
    )
  );
exception
  when duplicate_object then null;
end $$;

alter table public.office_locations enable row level security;

drop policy if exists "office_locations_select_active"
on public.office_locations;

create policy "office_locations_select_active"
on public.office_locations
for select
to authenticated
using (is_active = true);

drop policy if exists "office_locations_select_manager"
on public.office_locations;

create policy "office_locations_select_manager"
on public.office_locations
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "office_locations_insert_manager"
on public.office_locations;

create policy "office_locations_insert_manager"
on public.office_locations
for insert
to authenticated
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "office_locations_update_manager"
on public.office_locations;

create policy "office_locations_update_manager"
on public.office_locations
for update
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'))
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

insert into public.office_locations (
  office_name,
  province,
  district,
  latitude,
  longitude,
  radius_m,
  is_active
)
values
  (
    'Lusaka Test Office',
    'Lusaka',
    'Lusaka',
    -15.446036,
    28.321079,
    100,
    true
  ),
  (
    'Lusaka HQ',
    'Lusaka',
    'Lusaka',
    -15.4136425,
    28.3414573,
    100,
    true
  )
on conflict (office_name) do update
set
  province = excluded.province,
  district = excluded.district,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  radius_m = excluded.radius_m,
  is_active = excluded.is_active,
  updated_at = timezone('utc', now());
