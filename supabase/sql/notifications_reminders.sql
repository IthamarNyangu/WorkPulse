-- WorkPulse Notifications & Smart Reminders MVP
-- Run this entire file in the Supabase SQL Editor.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_key text not null,
  type text not null check (
    type in (
      'clock_in_reminder',
      'clock_out_reminder',
      'missed_punch_reminder',
      'leave_update',
      'general_info'
    )
  ),
  title text not null,
  message text not null,
  occurred_at timestamptz not null default now(),
  is_read boolean not null default false,
  status text not null default 'active'
    check (status in ('active', 'resolved')),
  action_label text,
  navigation_target text check (
    navigation_target is null or navigation_target in (
      'clock_in',
      'clock_out',
      'correction_list',
      'correction_details',
      'leave_list',
      'leave_details'
    )
  ),
  attendance_record_id uuid references public.attendance_records(id)
    on delete set null,
  correction_request_id uuid references public.correction_requests(id)
    on delete set null,
  leave_request_id uuid references public.leave_requests(id)
    on delete set null,
  office_location_id uuid references public.office_locations(id)
    on delete set null,
  resolved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, event_key)
);

create index if not exists notifications_user_status_occurred_idx
  on public.notifications (user_id, status, occurred_at desc);

create or replace function public.set_notification_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_notifications_updated_at
  on public.notifications;
create trigger set_notifications_updated_at
before update on public.notifications
for each row execute function public.set_notification_updated_at();

alter table public.notifications enable row level security;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
on public.notifications
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists notifications_insert_own on public.notifications;
create policy notifications_insert_own
on public.notifications
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
on public.notifications
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Approval changes are created server-side so they are available on the next
-- foreground refresh even when the employee app was not open during approval.
create or replace function public.notify_leave_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  leave_label text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  leave_label := case new.leave_type
    when 'annual' then 'annual leave'
    when 'sick' then 'sick leave'
    else 'leave'
  end;

  insert into public.notifications (
    user_id,
    event_key,
    type,
    title,
    message,
    action_label,
    navigation_target,
    leave_request_id
  ) values (
    new.user_id,
    'leave_update:' || new.id::text || ':' || new.status,
    'leave_update',
    'Leave Request Updated',
    case new.status
      when 'approved' then 'Your ' || leave_label || ' request was approved.'
      when 'rejected' then 'Your ' || leave_label || ' request was rejected.'
      else 'Your ' || leave_label || ' request is pending approval.'
    end,
    'View Leave Request',
    'leave_details',
    new.id
  )
  on conflict (user_id, event_key) do nothing;

  return new;
end;
$$;

drop trigger if exists notify_leave_status_change
  on public.leave_requests;
create trigger notify_leave_status_change
after update of status on public.leave_requests
for each row execute function public.notify_leave_status_change();

create or replace function public.notify_correction_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  insert into public.notifications (
    user_id,
    event_key,
    type,
    title,
    message,
    action_label,
    navigation_target,
    attendance_record_id,
    correction_request_id
  ) values (
    new.user_id,
    'correction_update:' || new.id::text || ':' || new.status,
    'general_info',
    'Correction Request Updated',
    case new.status
      when 'approved' then 'Your attendance correction was approved.'
      when 'rejected' then 'Your attendance correction was rejected.'
      else 'Your attendance correction is pending review.'
    end,
    'View Request',
    'correction_details',
    new.attendance_record_id,
    new.id
  )
  on conflict (user_id, event_key) do nothing;

  return new;
end;
$$;

drop trigger if exists notify_correction_status_change
  on public.correction_requests;
create trigger notify_correction_status_change
after update of status on public.correction_requests
for each row execute function public.notify_correction_status_change();
