-- WorkPulse schedule-aware reminder policy.
-- Run once in Supabase SQL Editor after push_notifications_fcm.sql.

create extension if not exists pgcrypto;

create table if not exists public.work_schedules (
  id uuid primary key default gen_random_uuid(),
  schedule_name text not null unique,
  timezone_name text not null default 'Africa/Lusaka',
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists work_schedules_one_default_idx
  on public.work_schedules (is_default)
  where is_default;

create table if not exists public.work_schedule_days (
  schedule_id uuid not null references public.work_schedules(id) on delete cascade,
  iso_weekday smallint not null check (iso_weekday between 1 and 7),
  is_working_day boolean not null default true,
  start_time time,
  end_time time,
  primary key (schedule_id, iso_weekday),
  check (
    (not is_working_day and start_time is null and end_time is null)
    or
    (is_working_day and start_time is not null and end_time is not null and end_time > start_time)
  )
);

insert into public.work_schedules (
  id, schedule_name, timezone_name, is_default, is_active
)
values (
  '00000000-0000-4000-8000-000000000001',
  'Standard Work Week',
  'Africa/Lusaka',
  true,
  true
)
on conflict (id) do update
set schedule_name = excluded.schedule_name,
    timezone_name = excluded.timezone_name,
    is_default = excluded.is_default,
    is_active = excluded.is_active,
    updated_at = now();

insert into public.work_schedule_days (
  schedule_id, iso_weekday, is_working_day, start_time, end_time
)
values
  ('00000000-0000-4000-8000-000000000001', 1, true,  time '08:00', time '17:00'),
  ('00000000-0000-4000-8000-000000000001', 2, true,  time '08:00', time '17:00'),
  ('00000000-0000-4000-8000-000000000001', 3, true,  time '08:00', time '17:00'),
  ('00000000-0000-4000-8000-000000000001', 4, true,  time '08:00', time '17:00'),
  ('00000000-0000-4000-8000-000000000001', 5, true,  time '08:00', time '14:00'),
  ('00000000-0000-4000-8000-000000000001', 6, false, null, null),
  ('00000000-0000-4000-8000-000000000001', 7, false, null, null)
on conflict (schedule_id, iso_weekday) do update
set is_working_day = excluded.is_working_day,
    start_time = excluded.start_time,
    end_time = excluded.end_time;

alter table public.profiles
  add column if not exists work_schedule_id uuid
  references public.work_schedules(id) on delete set null;

update public.profiles
set work_schedule_id = '00000000-0000-4000-8000-000000000001'
where work_schedule_id is null;

create table if not exists public.user_location_presence (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  presence_state text not null check (
    presence_state in ('inside_office', 'outside_offices')
  ),
  office_location_id uuid references public.office_locations(id) on delete set null,
  transitioned_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.work_schedules enable row level security;
alter table public.work_schedule_days enable row level security;
alter table public.user_location_presence enable row level security;

drop policy if exists work_schedules_read_authenticated
  on public.work_schedules;
create policy work_schedules_read_authenticated
on public.work_schedules for select to authenticated
using (is_active);

drop policy if exists work_schedule_days_read_authenticated
  on public.work_schedule_days;
create policy work_schedule_days_read_authenticated
on public.work_schedule_days for select to authenticated
using (true);

drop policy if exists location_presence_read_own
  on public.user_location_presence;
create policy location_presence_read_own
on public.user_location_presence for select to authenticated
using (user_id = auth.uid());

create or replace function public.record_my_location_presence(
  p_state text,
  p_office_location_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_state not in ('inside_office', 'outside_offices') then
    raise exception 'Unsupported location presence state';
  end if;
  if p_office_location_id is null then
    raise exception 'The matched or last office is required';
  end if;
  if not exists (
    select 1 from public.office_locations office
    where office.id = p_office_location_id
  ) then
    raise exception 'Office location does not exist';
  end if;

  insert into public.user_location_presence (
    user_id, presence_state, office_location_id, transitioned_at, updated_at
  )
  values (auth.uid(), p_state, p_office_location_id, now(), now())
  on conflict (user_id) do update
  set presence_state = excluded.presence_state,
      office_location_id = excluded.office_location_id,
      transitioned_at = case
        when public.user_location_presence.presence_state is distinct from excluded.presence_state
          or public.user_location_presence.office_location_id is distinct from excluded.office_location_id
        then now()
        else public.user_location_presence.transitioned_at
      end,
      updated_at = now();
end;
$$;

revoke all on function public.record_my_location_presence(text, uuid)
  from public;
grant execute on function public.record_my_location_presence(text, uuid)
  to authenticated;

create or replace function public.generate_scheduled_attendance_reminders(
  p_now timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  local_now timestamp := p_now at time zone 'Africa/Lusaka';
  local_date date := (p_now at time zone 'Africa/Lusaka')::date;
  previous_date date := ((p_now at time zone 'Africa/Lusaka')::date - 1);
  default_schedule_id uuid;
  inserted_count integer := 0;
  affected_count integer := 0;
begin
  select schedule.id into default_schedule_id
  from public.work_schedules schedule
  where schedule.is_default and schedule.is_active
  limit 1;

  -- First Clock In reminder at the employee's configured shift start.
  insert into public.notifications (
    user_id, event_key, type, title, message, occurred_at,
    action_label, navigation_target
  )
  select
    profile.id,
    'scheduled_clock_in:' || local_date::text,
    'clock_in_reminder',
    'Clock In Reminder',
    'Your workday has started. Remember to clock in when you arrive at an approved office.',
    p_now,
    'Clock In',
    'clock_in'
  from public.profiles profile
  join public.work_schedule_days schedule_day
    on schedule_day.schedule_id = coalesce(profile.work_schedule_id, default_schedule_id)
   and schedule_day.iso_weekday = extract(isodow from local_now)::integer
  where coalesce(profile.is_active, true)
    and schedule_day.is_working_day
    and local_now::time >= schedule_day.start_time
    and not exists (
      select 1 from public.attendance_records attendance
      where attendance.user_id = profile.id
        and attendance.work_date = local_date
        and attendance.clock_in is not null
    )
    and not exists (
      select 1 from public.leave_requests leave_request
      where leave_request.user_id = profile.id
        and leave_request.status in ('pending', 'approved')
        and local_date between leave_request.start_date and leave_request.end_date
    )
  on conflict (user_id, event_key) do nothing;
  get diagnostics affected_count = row_count;
  inserted_count := inserted_count + affected_count;

  -- First Clock Out reminder at shift end. Daytime office exits remain silent.
  insert into public.notifications (
    user_id, event_key, type, title, message, occurred_at,
    action_label, navigation_target, attendance_record_id, office_location_id
  )
  select
    attendance.user_id,
    'scheduled_clock_out:' || local_date::text,
    'clock_out_reminder',
    'Clock Out Reminder',
    case
      when presence.presence_state = 'outside_offices'
       and presence.transitioned_at >= attendance.clock_in
       and office.office_name is not null
      then 'Your shift has ended, and you left ' || office.office_name ||
           ' while still clocked in. Please clock out.'
      else 'Your shift has ended, and you are still clocked in. Please clock out.'
    end,
    p_now,
    'Clock Out',
    'clock_out',
    attendance.id,
    presence.office_location_id
  from public.attendance_records attendance
  join public.profiles profile on profile.id = attendance.user_id
  join public.work_schedule_days schedule_day
    on schedule_day.schedule_id = coalesce(profile.work_schedule_id, default_schedule_id)
   and schedule_day.iso_weekday = extract(isodow from local_now)::integer
  left join public.user_location_presence presence
    on presence.user_id = attendance.user_id
  left join public.office_locations office
    on office.id = presence.office_location_id
  where attendance.work_date = local_date
    and attendance.clock_in is not null
    and attendance.clock_out is null
    and schedule_day.is_working_day
    and local_now::time >= schedule_day.end_time
  on conflict (user_id, event_key) do nothing;
  get diagnostics affected_count = row_count;
  inserted_count := inserted_count + affected_count;

  -- Exactly one follow-up, 30 minutes after today's first scheduled reminder.
  insert into public.notifications (
    user_id, event_key, type, title, message, occurred_at,
    action_label, navigation_target, attendance_record_id, office_location_id
  )
  select
    original.user_id,
    'scheduled_follow_up:' || original.event_key,
    original.type,
    case original.type
      when 'clock_in_reminder' then 'Clock In Still Pending'
      else 'Clock Out Still Pending'
    end,
    case original.type
      when 'clock_in_reminder' then
        'You still have not clocked in. Please clock in if you are starting work today.'
      else
        'You are still clocked in 30 minutes after your shift ended. Please clock out.'
    end,
    p_now,
    original.action_label,
    original.navigation_target,
    original.attendance_record_id,
    original.office_location_id
  from public.notifications original
  where original.status = 'active'
    and original.event_key in (
      'scheduled_clock_in:' || local_date::text,
      'scheduled_clock_out:' || local_date::text
    )
    and original.occurred_at <= p_now - interval '30 minutes'
    and (
      (original.type = 'clock_in_reminder' and not exists (
        select 1 from public.attendance_records attendance
        where attendance.user_id = original.user_id
          and attendance.work_date = local_date
          and attendance.clock_in is not null
      ))
      or
      (original.type = 'clock_out_reminder' and exists (
        select 1 from public.attendance_records attendance
        where attendance.user_id = original.user_id
          and attendance.work_date = local_date
          and attendance.clock_in is not null
          and attendance.clock_out is null
      ))
    )
  on conflict (user_id, event_key) do nothing;
  get diagnostics affected_count = row_count;
  inserted_count := inserted_count + affected_count;

  -- One status-specific reminder for the previous weekday's exception.
  if extract(isodow from previous_date) between 1 and 5 then
    insert into public.notifications (
      user_id, event_key, type, title, message, occurred_at,
      action_label, navigation_target, attendance_record_id
    )
    select
      attendance.user_id,
      'scheduled_attendance_attention:' || attendance.work_date::text,
      'missed_punch_reminder',
      'Attendance Needs Attention',
      case
        when attendance.clock_in is null then
          'Yesterday has no Clock In record. Submit a correction if you worked.'
        else
          'Yesterday has no Clock Out record. Submit a correction.'
      end,
      p_now,
      'Request Correction',
      'correction_list',
      attendance.id
    from public.attendance_records attendance
    where attendance.work_date = previous_date
      and attendance.status in ('missed_punch', 'absent')
    on conflict (user_id, event_key) do nothing;
    get diagnostics affected_count = row_count;
    inserted_count := inserted_count + affected_count;
  end if;

  return inserted_count;
end;
$$;

revoke all on function public.generate_scheduled_attendance_reminders(timestamptz)
  from public, anon, authenticated;
grant execute on function public.generate_scheduled_attendance_reminders(timestamptz)
  to service_role;

-- Resolve legacy on-device reminders while retaining canonical server rows.
update public.notifications
set status = 'resolved', is_read = true, resolved_at = now()
where status = 'active'
  and (
    event_key like 'attendance_attention:%'
    or event_key like 'clock_in:%'
    or event_key like 'clock_in_follow_up:%'
    or event_key like 'office_exit:%'
    or event_key like 'office_exit_follow_up:%'
    or event_key like 'late_clock_out:%'
  );
