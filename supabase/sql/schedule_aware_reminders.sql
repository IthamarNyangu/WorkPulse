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

create table if not exists public.public_holidays (
  id uuid primary key default gen_random_uuid(),
  holiday_date date not null,
  holiday_name text not null,
  holiday_type text not null check (
    holiday_type in (
      'fixed_date',
      'movable_easter',
      'recurring_weekday',
      'observed',
      'gazetted_once'
    )
  ),
  observed_for_date date,
  is_active boolean not null default true,
  is_generated boolean not null default false,
  source_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (holiday_date, holiday_name)
);

create index if not exists public_holidays_active_date_idx
  on public.public_holidays (holiday_date)
  where is_active;

create or replace function public.zambia_easter_sunday(p_year integer)
returns date
language plpgsql
immutable
strict
set search_path = public
as $$
declare
  a integer := p_year % 19;
  b integer := p_year / 100;
  c integer := p_year % 100;
  d integer := b / 4;
  e integer := b % 4;
  f integer := (b + 8) / 25;
  g integer := (b - f + 1) / 3;
  h integer;
  i integer := c / 4;
  k integer := c % 4;
  l integer;
  m integer;
  easter_month integer;
  easter_day integer;
begin
  h := (19 * a + b - d - g + 15) % 30;
  l := (32 + 2 * e + 2 * i - h - k) % 7;
  m := (a + 11 * h + 22 * l) / 451;
  easter_month := (h + l - 7 * m + 114) / 31;
  easter_day := ((h + l - 7 * m + 114) % 31) + 1;
  return make_date(p_year, easter_month, easter_day);
end;
$$;

create or replace function public.seed_zambia_public_holidays(p_year integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  easter_sunday date := public.zambia_easter_sunday(p_year);
  july_first date := make_date(p_year, 7, 1);
  august_first date := make_date(p_year, 8, 1);
  heroes_day date;
  farmers_day date;
begin
  if p_year < 1964 or p_year > 2200 then
    raise exception 'Holiday year is outside the supported range';
  end if;

  heroes_day := july_first + ((8 - extract(isodow from july_first)::integer) % 7);
  farmers_day := august_first + ((8 - extract(isodow from august_first)::integer) % 7);

  -- Regenerate only calculated rows. Manually gazetted one-off holidays remain intact.
  delete from public.public_holidays
  where extract(year from holiday_date)::integer = p_year
    and is_generated;

  insert into public.public_holidays (
    holiday_date, holiday_name, holiday_type, is_generated, source_reference
  )
  values
    (make_date(p_year, 1, 1), 'New Year''s Day', 'fixed_date', true, 'Public Holidays Act'),
    (make_date(p_year, 3, 8), 'International Women''s Day', 'fixed_date', true, 'Annual public holiday'),
    (make_date(p_year, 3, 12), 'Youth Day', 'fixed_date', true, 'Public Holidays Act'),
    (easter_sunday - 2, 'Good Friday', 'movable_easter', true, 'Public Holidays Act'),
    (easter_sunday - 1, 'Holy Saturday', 'movable_easter', true, 'Public Holidays Act'),
    (easter_sunday, 'Easter Sunday', 'movable_easter', true, 'Annual public holiday'),
    (easter_sunday + 1, 'Easter Monday', 'movable_easter', true, 'Annual public holiday'),
    (make_date(p_year, 4, 28), 'Kenneth Kaunda Day', 'fixed_date', true, 'Statutory Instrument No. 72 of 2021'),
    (make_date(p_year, 5, 1), 'Labour Day', 'fixed_date', true, 'Public Holidays Act'),
    (make_date(p_year, 5, 25), 'Africa Freedom Day', 'fixed_date', true, 'Public Holidays Act'),
    (heroes_day, 'Heroes Day', 'recurring_weekday', true, 'Public Holidays Act'),
    (heroes_day + 1, 'Unity Day', 'recurring_weekday', true, 'Public Holidays Act'),
    (farmers_day, 'Farmers Day', 'recurring_weekday', true, 'Public Holidays Act'),
    (make_date(p_year, 10, 18), 'National Day of Prayer, Fasting, Repentance and Reconciliation', 'fixed_date', true, 'Annual public holiday'),
    (make_date(p_year, 10, 24), 'Independence Day', 'fixed_date', true, 'Public Holidays Act'),
    (make_date(p_year, 12, 25), 'Christmas Day', 'fixed_date', true, 'Public Holidays Act');

  -- Current Zambian law observes the following Monday when a scheduled
  -- public holiday falls on Sunday. Easter Monday already covers Easter Sunday.
  insert into public.public_holidays (
    holiday_date,
    holiday_name,
    holiday_type,
    observed_for_date,
    is_generated,
    source_reference
  )
  select
    holiday.holiday_date + 1,
    holiday.holiday_name || ' (Observed)',
    'observed',
    holiday.holiday_date,
    true,
    'Public Holidays Act, section 2(2)'
  from public.public_holidays holiday
  where extract(year from holiday.holiday_date)::integer = p_year
    and holiday.is_active
    and holiday.holiday_type in ('fixed_date', 'recurring_weekday', 'gazetted_once')
    and extract(isodow from holiday.holiday_date) = 7;
end;
$$;

create or replace function public.is_zambia_public_holiday(p_date date)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.public_holidays holiday
    where holiday.holiday_date = p_date
      and holiday.is_active
  );
$$;

revoke all on function public.seed_zambia_public_holidays(integer)
  from public, anon, authenticated;
grant execute on function public.seed_zambia_public_holidays(integer)
  to service_role;

do $$
declare
  holiday_year integer;
  current_year integer := extract(year from (now() at time zone 'Africa/Lusaka'))::integer;
begin
  for holiday_year in (current_year - 1)..(current_year + 5) loop
    perform public.seed_zambia_public_holidays(holiday_year);
  end loop;
end;
$$;

alter table public.profiles
  add column if not exists work_schedule_id uuid
  references public.work_schedules(id) on delete set null;

update public.profiles
set work_schedule_id = '00000000-0000-4000-8000-000000000001'
where work_schedule_id is null;

create or replace function public.calculate_leave_working_days(
  p_user_id uuid,
  p_start_date date,
  p_end_date date
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  with selected_schedule as (
    select coalesce(
      profile.work_schedule_id,
      (
        select schedule.id
        from public.work_schedules schedule
        where schedule.is_default and schedule.is_active
        limit 1
      )
    ) as schedule_id
    from public.profiles profile
    where profile.id = p_user_id
  ), requested_dates as (
    select day_value::date as work_date
    from generate_series(
      least(p_start_date, p_end_date)::timestamp,
      greatest(p_start_date, p_end_date)::timestamp,
      interval '1 day'
    ) as day_value
  )
  select count(*)::integer
  from requested_dates requested_date
  cross join selected_schedule
  join public.work_schedule_days schedule_day
    on schedule_day.schedule_id = selected_schedule.schedule_id
   and schedule_day.iso_weekday = extract(isodow from requested_date.work_date)::integer
  where schedule_day.is_working_day
    and not public.is_zambia_public_holiday(requested_date.work_date);
$$;

create or replace function public.count_my_leave_working_days(
  p_start_date date,
  p_end_date date
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  return public.calculate_leave_working_days(
    auth.uid(),
    p_start_date,
    p_end_date
  );
end;
$$;

create or replace function public.set_leave_request_working_duration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.end_date < new.start_date then
    raise exception 'Leave end date cannot be before the start date';
  end if;

  new.duration_days := public.calculate_leave_working_days(
    new.user_id,
    new.start_date,
    new.end_date
  );
  if new.duration_days < 1 then
    raise exception 'The selected leave range contains no scheduled working days';
  end if;
  return new;
end;
$$;

revoke all on function public.calculate_leave_working_days(uuid, date, date)
  from public, anon, authenticated;
grant execute on function public.calculate_leave_working_days(uuid, date, date)
  to service_role;

revoke all on function public.count_my_leave_working_days(date, date)
  from public, anon;
grant execute on function public.count_my_leave_working_days(date, date)
  to authenticated;

alter table public.leave_requests
  drop constraint if exists leave_requests_duration_days_check;
alter table public.leave_requests
  add constraint leave_requests_duration_days_check
  check (duration_days >= 0);

-- Correct previously stored calendar-day totals before enforcing new writes.
update public.leave_requests leave_request
set duration_days = public.calculate_leave_working_days(
  leave_request.user_id,
  leave_request.start_date,
  leave_request.end_date
);

drop trigger if exists set_leave_request_working_duration
  on public.leave_requests;
create trigger set_leave_request_working_duration
before insert or update of user_id, start_date, end_date, duration_days
on public.leave_requests
for each row execute function public.set_leave_request_working_duration();

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
alter table public.public_holidays enable row level security;
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

drop policy if exists public_holidays_read_authenticated
  on public.public_holidays;
create policy public_holidays_read_authenticated
on public.public_holidays for select to authenticated
using (is_active);

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
  if not exists (
    select 1
    from public.public_holidays holiday
    where extract(year from holiday.holiday_date)::integer = extract(year from local_date)::integer
      and holiday.is_generated
  ) then
    perform public.seed_zambia_public_holidays(extract(year from local_date)::integer);
  end if;

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
    and not public.is_zambia_public_holiday(local_date)
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
    and not public.is_zambia_public_holiday(local_date)
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
    and not public.is_zambia_public_holiday(local_date)
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
  if extract(isodow from previous_date) between 1 and 5
     and not public.is_zambia_public_holiday(previous_date) then
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
