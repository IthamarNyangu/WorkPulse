-- WorkPulse approval workflow migration.
-- Run this once in Supabase SQL Editor before testing supervisor approvals.

alter table public.leave_requests
add column if not exists reviewed_by uuid references public.profiles(id) on delete set null,
add column if not exists reviewed_at timestamptz,
add column if not exists reviewer_note text;

alter table public.correction_requests
add column if not exists reviewed_by uuid references public.profiles(id) on delete set null,
add column if not exists reviewed_at timestamptz,
add column if not exists reviewer_note text;

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

drop policy if exists "profiles_select_reviewer" on public.profiles;
create policy "profiles_select_reviewer"
on public.profiles
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "attendance_select_reviewer" on public.attendance_records;
create policy "attendance_select_reviewer"
on public.attendance_records
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "attendance_update_reviewer" on public.attendance_records;
create policy "attendance_update_reviewer"
on public.attendance_records
for update
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'))
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "attendance_delete_generated_own" on public.attendance_records;
create policy "attendance_delete_generated_own"
on public.attendance_records
for delete
to authenticated
using (
  auth.uid() = user_id
  and clock_in is null
  and clock_out is null
  and status in ('on_leave', 'leave_pending')
);

drop policy if exists "leave_select_reviewer" on public.leave_requests;
create policy "leave_select_reviewer"
on public.leave_requests
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "leave_update_reviewer" on public.leave_requests;
create policy "leave_update_reviewer"
on public.leave_requests
for update
to authenticated
using (
  status = 'pending'
  and public.current_user_role() in ('supervisor', 'hr', 'admin')
)
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "correction_select_reviewer" on public.correction_requests;
create policy "correction_select_reviewer"
on public.correction_requests
for select
to authenticated
using (public.current_user_role() in ('supervisor', 'hr', 'admin'));

drop policy if exists "correction_update_reviewer" on public.correction_requests;
create policy "correction_update_reviewer"
on public.correction_requests
for update
to authenticated
using (
  status = 'pending'
  and public.current_user_role() in ('supervisor', 'hr', 'admin')
)
with check (public.current_user_role() in ('supervisor', 'hr', 'admin'));

-- Tighten employee self-edit policies so employees can edit pending requests
-- but cannot approve/reject their own requests through client-side updates.
drop policy if exists "leave_update_pending_own" on public.leave_requests;
create policy "leave_update_pending_own"
on public.leave_requests
for update
to authenticated
using (auth.uid() = user_id and status = 'pending')
with check (auth.uid() = user_id and status = 'pending');

drop policy if exists "correction_update_pending_own" on public.correction_requests;
create policy "correction_update_pending_own"
on public.correction_requests
for update
to authenticated
using (auth.uid() = user_id and status = 'pending')
with check (auth.uid() = user_id and status = 'pending');
