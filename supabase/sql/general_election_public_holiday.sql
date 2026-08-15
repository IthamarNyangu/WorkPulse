-- WorkPulse: add Zambia General Election Day to generated public holidays.
-- Run this once in the Supabase SQL Editor after schedule_aware_reminders.sql.

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
  general_election_day date;
begin
  if p_year < 1964 or p_year > 2200 then
    raise exception 'Holiday year is outside the supported range';
  end if;

  heroes_day := july_first + ((8 - extract(isodow from july_first)::integer) % 7);
  farmers_day := august_first + ((8 - extract(isodow from august_first)::integer) % 7);
  general_election_day := august_first
    + ((4 - extract(isodow from august_first)::integer + 7) % 7)
    + 7;

  -- Regenerate calculated holidays while preserving manually gazetted rows.
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

  if p_year >= 2016 and mod(p_year - 2016, 5) = 0 then
    insert into public.public_holidays (
      holiday_date, holiday_name, holiday_type, is_generated, source_reference
    )
    values (
      general_election_day,
      'General Election Day',
      'recurring_weekday',
      true,
      'Constitution of Zambia, Article 56'
    );
  end if;

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

revoke all on function public.seed_zambia_public_holidays(integer)
  from public, anon, authenticated;
grant execute on function public.seed_zambia_public_holidays(integer)
  to service_role;

do $$
declare
  holiday_year integer;
  current_year integer := extract(
    year from (now() at time zone 'Africa/Lusaka')
  )::integer;
begin
  for holiday_year in (current_year - 5)..(current_year + 5) loop
    perform public.seed_zambia_public_holidays(holiday_year);
  end loop;
end;
$$;

-- Expected current-cycle result: 2026-08-13.
select holiday_date, holiday_name, holiday_type, source_reference
from public.public_holidays
where holiday_name = 'General Election Day'
order by holiday_date;
