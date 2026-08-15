-- WorkPulse native background-geofence reminder synchronization.
-- Run once in Supabase SQL Editor after push_notifications_fcm.sql.

create or replace function public.record_my_geofence_reminder(
  p_event_key text,
  p_title text,
  p_message text,
  p_occurred_at timestamptz,
  p_office_location_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  notification_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_event_key not like 'geofence_entry:%'
     and p_event_key not like 'geofence_entry_follow_up:%' then
    raise exception 'Unsupported geofence reminder key';
  end if;
  if length(trim(p_title)) not between 1 and 80
     or length(trim(p_message)) not between 1 and 300 then
    raise exception 'Invalid geofence reminder content';
  end if;
  if not exists (
    select 1 from public.office_locations office
    where office.id = p_office_location_id and office.is_active
  ) then
    raise exception 'Active office location does not exist';
  end if;

  insert into public.notifications (
    user_id, event_key, type, title, message, occurred_at,
    action_label, navigation_target, office_location_id, push_sent_at
  )
  values (
    auth.uid(), p_event_key, 'clock_in_reminder', trim(p_title),
    trim(p_message), p_occurred_at, 'Clock In', 'clock_in',
    p_office_location_id, now()
  )
  on conflict (user_id, event_key) do nothing
  returning id into notification_id;

  if notification_id is null then
    select notification.id into notification_id
    from public.notifications notification
    where notification.user_id = auth.uid()
      and notification.event_key = p_event_key;
  end if;
  return notification_id;
end;
$$;

revoke all on function public.record_my_geofence_reminder(
  text, text, text, timestamptz, uuid
) from public, anon;
grant execute on function public.record_my_geofence_reminder(
  text, text, text, timestamptz, uuid
) to authenticated;
