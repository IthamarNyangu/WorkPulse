-- WorkPulse job-title catalogue.
-- Run this once in the Supabase SQL Editor before using the Job Titles UI.

create table if not exists public.job_titles (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists job_titles_name_lower_unique
on public.job_titles (lower(trim(name)));

-- Preserve every title already imported into employee profiles.
insert into public.job_titles (name)
select distinct trim(profile.job_title)
from public.profiles profile
where nullif(trim(profile.job_title), '') is not null
  and not exists (
    select 1
    from public.job_titles title
    where lower(trim(title.name)) = lower(trim(profile.job_title))
  );

drop trigger if exists set_job_titles_updated_at on public.job_titles;
create trigger set_job_titles_updated_at
before update on public.job_titles
for each row execute function public.set_updated_at();

alter table public.job_titles enable row level security;

drop policy if exists "job_titles_select_active" on public.job_titles;
create policy "job_titles_select_active"
on public.job_titles
for select
to authenticated
using (
  is_active = true
  or public.current_user_has_any_role(array['hr', 'admin'])
);

drop policy if exists "job_titles_insert_org_manager" on public.job_titles;
create policy "job_titles_insert_org_manager"
on public.job_titles
for insert
to authenticated
with check (public.current_user_has_any_role(array['hr', 'admin']));

drop policy if exists "job_titles_update_org_manager" on public.job_titles;
create policy "job_titles_update_org_manager"
on public.job_titles
for update
to authenticated
using (public.current_user_has_any_role(array['hr', 'admin']))
with check (public.current_user_has_any_role(array['hr', 'admin']));

grant select, insert, update on public.job_titles to authenticated;
