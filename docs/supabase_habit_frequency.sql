alter table public.habits
  add column if not exists frequency_mode text not null default 'daily',
  add column if not exists weekly_target integer not null default 7;

update public.habits
set frequency_mode = coalesce(frequency_mode, 'daily'),
    weekly_target = coalesce(weekly_target, 7);

update public.habits
set frequency_mode = 'daily'
where frequency_mode not in ('daily', 'weekly');

update public.habits
set weekly_target = case
  when frequency_mode = 'weekly' and weekly_target in (1, 2, 3, 5)
    then weekly_target
  when frequency_mode = 'weekly'
    then 3
  else 7
end;

alter table public.habits
  drop constraint if exists habits_frequency_mode_check;

alter table public.habits
  add constraint habits_frequency_mode_check
  check (frequency_mode in ('daily', 'weekly'));

alter table public.habits
  drop constraint if exists habits_weekly_target_check;

alter table public.habits
  add constraint habits_weekly_target_check
  check (
    (frequency_mode = 'daily' and weekly_target = 7)
    or
    (frequency_mode = 'weekly' and weekly_target in (1, 2, 3, 5))
  );
