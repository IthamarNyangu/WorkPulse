-- WorkPulse Firebase Cloud Messaging foundation.
-- Run this file after notifications_reminders.sql in the Supabase SQL Editor.

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_active_idx
  on public.device_tokens (user_id, is_active);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_select_own on public.device_tokens;
create policy device_tokens_select_own
on public.device_tokens
for select
to authenticated
using (auth.uid() = user_id);

create or replace function public.register_device_token(
  p_token text,
  p_platform text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;
  if nullif(trim(p_token), '') is null then
    raise exception 'A device token is required.';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'Unsupported device platform.';
  end if;

  insert into public.device_tokens (
    user_id,
    token,
    platform,
    is_active,
    last_seen_at
  ) values (
    auth.uid(),
    trim(p_token),
    p_platform,
    true,
    now()
  )
  on conflict (token) do update
  set
    user_id = excluded.user_id,
    platform = excluded.platform,
    is_active = true,
    last_seen_at = now(),
    updated_at = now();
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  update public.device_tokens
  set is_active = false, updated_at = now()
  where token = p_token
    and user_id = auth.uid();
end;
$$;

revoke all on function public.register_device_token(text, text) from public;
revoke all on function public.unregister_device_token(text) from public;
grant execute on function public.register_device_token(text, text)
  to authenticated;
grant execute on function public.unregister_device_token(text)
  to authenticated;

do $$
declare
  first_push_migration boolean;
begin
  select not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notifications'
      and column_name = 'push_sent_at'
  ) into first_push_migration;

  alter table public.notifications
    add column if not exists push_sent_at timestamptz,
    add column if not exists push_claimed_at timestamptz,
    add column if not exists push_attempts integer not null default 0,
    add column if not exists push_last_error text;

  -- Do not deliver the user's old notification-center history as new push alerts.
  if first_push_migration then
    update public.notifications
    set push_sent_at = now()
    where push_sent_at is null;
  end if;
end;
$$;

create index if not exists notifications_pending_push_idx
  on public.notifications (occurred_at)
  where status = 'active' and push_sent_at is null;

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
  inserted_count integer := 0;
  affected_count integer := 0;
begin
  -- Generic server reminder. Geofence-specific arrival reminders remain on-device.
  if extract(isodow from local_now) between 1 and 5
     and local_now::time >= time '08:00' then
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
    where coalesce(profile.is_active, true)
      and not exists (
        select 1
        from public.attendance_records attendance
        where attendance.user_id = profile.id
          and attendance.work_date = local_date
          and attendance.clock_in is not null
      )
      and not exists (
        select 1
        from public.leave_requests leave_request
        where leave_request.user_id = profile.id
          and leave_request.status in ('pending', 'approved')
          and local_date between leave_request.start_date and leave_request.end_date
      )
    on conflict (user_id, event_key) do nothing;
    get diagnostics affected_count = row_count;
    inserted_count := inserted_count + affected_count;
  end if;

  if local_now::time >= time '17:00' then
    insert into public.notifications (
      user_id, event_key, type, title, message, occurred_at,
      action_label, navigation_target, attendance_record_id
    )
    select
      attendance.user_id,
      'scheduled_clock_out:' || local_date::text,
      'clock_out_reminder',
      'Clock Out Reminder',
      'You are still clocked in. Did you forget to clock out?',
      p_now,
      'Clock Out',
      'clock_out',
      attendance.id
    from public.attendance_records attendance
    where attendance.work_date = local_date
      and attendance.clock_in is not null
      and attendance.clock_out is null
    on conflict (user_id, event_key) do nothing;
    get diagnostics affected_count = row_count;
    inserted_count := inserted_count + affected_count;
  end if;

  -- Production follow-up delay remains 30 minutes.
  insert into public.notifications (
    user_id, event_key, type, title, message, occurred_at,
    action_label, navigation_target, attendance_record_id
  )
  select
    original.user_id,
    'scheduled_follow_up:' || original.event_key,
    original.type,
    original.title,
    case original.type
      when 'clock_in_reminder' then 'You still have not clocked in. Open WorkPulse when you arrive at an approved office.'
      else 'You are still clocked in. Please clock out if your workday has ended.'
    end,
    p_now,
    original.action_label,
    original.navigation_target,
    original.attendance_record_id
  from public.notifications original
  where original.status = 'active'
    and original.type in ('clock_in_reminder', 'clock_out_reminder')
    and original.event_key like 'scheduled_%'
    and original.event_key not like 'scheduled_follow_up:%'
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
          'Yesterday''s attendance is incomplete. Submit a correction.'
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

create or replace function public.resolve_attendance_push_reminders()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.clock_in is not null then
    update public.notifications
    set status = 'resolved', is_read = true, resolved_at = now()
    where user_id = new.user_id
      and status = 'active'
      and type = 'clock_in_reminder';
  end if;

  if new.clock_out is not null then
    update public.notifications
    set status = 'resolved', is_read = true, resolved_at = now()
    where user_id = new.user_id
      and status = 'active'
      and type = 'clock_out_reminder';
  end if;
  return new;
end;
$$;

drop trigger if exists resolve_attendance_push_reminders
  on public.attendance_records;
create trigger resolve_attendance_push_reminders
after insert or update of clock_in, clock_out on public.attendance_records
for each row execute function public.resolve_attendance_push_reminders();

create or replace function public.claim_pending_push_notifications(
  p_limit integer default 100
)
returns setof public.notifications
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with candidates as (
    select notification.id
    from public.notifications notification
    where notification.status = 'active'
      and notification.push_sent_at is null
      and notification.push_attempts < 10
      and notification.occurred_at <= now()
      and (
        notification.push_claimed_at is null
        or notification.push_claimed_at < now() - interval '5 minutes'
      )
    order by notification.occurred_at
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 100), 500))
  )
  update public.notifications notification
  set
    push_claimed_at = now(),
    push_attempts = notification.push_attempts + 1,
    push_last_error = null
  from candidates
  where notification.id = candidates.id
  returning notification.*;
end;
$$;

revoke all on function public.generate_scheduled_attendance_reminders(timestamptz)
  from public;
revoke all on function public.claim_pending_push_notifications(integer)
  from public;
