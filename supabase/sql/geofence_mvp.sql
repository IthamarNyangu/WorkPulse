-- WorkPulse geolocation/geofence MVP migration.
-- Run this once in Supabase SQL Editor for existing projects.

alter table public.attendance_records
add column if not exists clock_in_accuracy_m double precision,
add column if not exists clock_in_inside_geofence boolean,
add column if not exists clock_out_accuracy_m double precision,
add column if not exists clock_out_inside_geofence boolean;
