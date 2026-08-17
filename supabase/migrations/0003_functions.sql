-- Leaderboard view + RPCs.

-- Only the three fields the leaderboard UI needs are exposed. `security_invoker
-- = off` (the default for views) means the view bypasses the per-row profile
-- policy, which is exactly what we want: it is a curated public projection.
create or replace view public.weekly_leaderboard as
select
  w.user_id,
  w.week_start,
  w.xp as weekly_xp,
  coalesce(nullif(p.username, ''), 'Öğrenci') as username,
  p.avatar_id
from public.weekly_xp w
join public.profiles p on p.id = w.user_id
where w.xp > 0;

grant select on public.weekly_leaderboard to anon, authenticated;

-- Rank of one user inside a given week. Used to show "you are #182" when the
-- user is outside the visible top slice.
create or replace function public.weekly_rank(p_user_id uuid, p_week_start date)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select rank::integer
  from (
    select user_id, rank() over (order by xp desc) as rank
    from public.weekly_xp
    where week_start = p_week_start and xp > 0
  ) ranked
  where ranked.user_id = p_user_id;
$$;

grant execute on function public.weekly_rank(uuid, date) to authenticated;

-- Google Play requires an in-app account deletion path. Deleting the auth user
-- cascades to every table via the `on delete cascade` foreign keys.
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
