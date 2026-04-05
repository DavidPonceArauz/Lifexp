create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.calendar_events
  where user_id = v_user_id;

  delete from public.habit_logs
  where user_id = v_user_id;

  delete from public.habit_freeze_days
  where user_id = v_user_id;

  delete from public.habit_freeze_progress
  where user_id = v_user_id;

  delete from public.habit_freezes
  where user_id = v_user_id;

  delete from public.objectives
  where goal_id in (
    select id
    from public.goals
    where user_id = v_user_id
  );

  delete from public.goals
  where user_id = v_user_id;

  delete from public.todos
  where user_id = v_user_id;

  delete from public.habits
  where user_id = v_user_id;

  delete from public.xp_log
  where user_id = v_user_id;

  delete from public.profiles
  where id = v_user_id;

  delete from auth.users
  where id = v_user_id;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
