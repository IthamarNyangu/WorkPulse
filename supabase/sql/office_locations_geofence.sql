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
  latitude double precision not null,
  longitude double precision not null,
  radius_m double precision not null check (radius_m >= 80),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

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

insert into public.office_locations (
  office_name,
  province,
  latitude,
  longitude,
  radius_m,
  is_active
)
values
  (
    'Lusaka Test Office',
    'Lusaka',
    -15.446036,
    28.321079,
    100,
    true
  ),
  (
    'Lusaka HQ',
    'Lusaka',
    -15.4136425,
    28.3414573,
    100,
    true
  )
on conflict (office_name) do update
set
  province = excluded.province,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  radius_m = excluded.radius_m,
  is_active = excluded.is_active,
  updated_at = timezone('utc', now());
