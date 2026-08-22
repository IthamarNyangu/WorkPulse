-- WorkPulse per-user notification preferences.
-- Run after notifications_reminders.sql, push_notifications_fcm.sql,
-- schedule_aware_reminders.sql, and background_geofence_reminders.sql.

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  basic_attendance_enabled boolean not null default true,
  smart_location_enabled boolean not null default false,
  request_updates_enabled boolean not null default true,
  push_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_notification_preference_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_notification_preferences_updated_at
  on public.notification_preferences;
create trigger set_notification_preferences_updated_at
before update on public.notification_preferences
for each row execute function public.set_notification_preference_updated_at();

alter table public.notification_preferences enable row level security;

drop policy if exists notification_preferences_select_own
  on public.notification_preferences;
create policy notification_preferences_select_own
on public.notification_preferences
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists notification_preferences_insert_own
  on public.notification_preferences;
create policy notification_preferences_insert_own
on public.notification_preferences
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists notification_preferences_update_own
  on public.notification_preferences;
create policy notification_preferences_update_own
on public.notification_preferences
for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Existing users receive safe defaults. Smart location requires explicit opt-in.
insert into public.notification_preferences (user_id)
select profile.id
from public.profiles profile
on conflict (user_id) do nothing;

create or replace function public.create_default_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists create_default_notification_preferences
  on public.profiles;
create trigger create_default_notification_preferences
after insert on public.profiles
for each row execute function public.create_default_notification_preferences();

-- Every notification producer passes through this gate, including cron,
-- approval triggers, and native geofence synchronization.
create or replace function public.enforce_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  preferences public.notification_preferences%rowtype;
begin
  select * into preferences
  from public.notification_preferences value
  where value.user_id = new.user_id;

  if new.event_key like 'scheduled_%'
     and not coalesce(preferences.basic_attendance_enabled, true) then
    return null;
  end if;

  if new.event_key like 'geofence_entry:%'
     and not coalesce(preferences.smart_location_enabled, false) then
    return null;
  end if;

  if (new.event_key like 'leave_update:%'
      or new.event_key like 'correction_update:%')
     and not coalesce(preferences.request_updates_enabled, true) then
    return null;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_notification_preferences
  on public.notifications;
create trigger enforce_notification_preferences
before insert on public.notifications
for each row execute function public.enforce_notification_preferences();

-- Turning a category off removes its current cards from the active inbox.
-- Disabling push also marks already-created rows as handled so re-enabling
-- push later cannot deliver an old backlog.
create or replace function public.apply_notification_preference_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not new.basic_attendance_enabled
     and old.basic_attendance_enabled then
    update public.notifications
    set status = 'resolved', is_read = true, resolved_at = now()
    where user_id = new.user_id
      and status = 'active'
      and event_key like 'scheduled_%';
  end if;

  if not new.smart_location_enabled
     and old.smart_location_enabled then
    update public.notifications
    set status = 'resolved', is_read = true, resolved_at = now()
    where user_id = new.user_id
      and status = 'active'
      and event_key like 'geofence_entry:%';
  end if;

  if not new.request_updates_enabled
     and old.request_updates_enabled then
    update public.notifications
    set status = 'resolved', is_read = true, resolved_at = now()
    where user_id = new.user_id
      and status = 'active'
      and (
        event_key like 'leave_update:%'
        or event_key like 'correction_update:%'
      );
  end if;

  if not new.push_enabled and old.push_enabled then
    update public.notifications
    set
      push_sent_at = coalesce(push_sent_at, now()),
      push_claimed_at = null,
      push_last_error = 'Push disabled by user preference.'
    where user_id = new.user_id
      and status = 'active'
      and push_sent_at is null;
  end if;

  return new;
end;
$$;

drop trigger if exists apply_notification_preference_changes
  on public.notification_preferences;
create trigger apply_notification_preference_changes
after update on public.notification_preferences
for each row execute function public.apply_notification_preference_changes();

-- A server-created notification remains visible under the bell when push is
-- off, but the cron worker does not claim it for Firebase delivery.
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
    left join public.notification_preferences preferences
      on preferences.user_id = notification.user_id
    where notification.status = 'active'
      and notification.push_sent_at is null
      and notification.push_attempts < 10
      and notification.occurred_at <= now()
      and coalesce(preferences.push_enabled, true)
      and (
        notification.push_claimed_at is null
        or notification.push_claimed_at < now() - interval '5 minutes'
      )
    order by notification.occurred_at
    for update of notification skip locked
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

revoke all on function public.claim_pending_push_notifications(integer)
  from public;

-- Keep one active Clock In card when a geofence reminder follows a scheduled
-- reminder. The native notification may already have been displayed, but the
-- WorkPulse inbox will not show both as pending actions.
create or replace function public.deduplicate_clock_in_reminders()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  local_date date := (new.occurred_at at time zone 'Africa/Lusaka')::date;
begin
  if new.event_key not like 'geofence_entry:%' then
    return new;
  end if;

  update public.notifications
  set status = 'resolved', is_read = true, resolved_at = now()
  where user_id = new.user_id
    and id <> new.id
    and status = 'active'
    and event_key in (
      'scheduled_clock_in:' || local_date::text,
      'scheduled_follow_up:scheduled_clock_in:' || local_date::text
    );
  return new;
end;
$$;

drop trigger if exists deduplicate_clock_in_reminders
  on public.notifications;
create trigger deduplicate_clock_in_reminders
after insert on public.notifications
for each row execute function public.deduplicate_clock_in_reminders();

grant select, insert, update on public.notification_preferences
  to authenticated;
