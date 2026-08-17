-- Row Level Security.
--
-- Rules of thumb:
--   * content tables (subjects, topics, questions, app_content, catalogues) are
--     world-readable but writable only by the service role / dashboard;
--   * every user-owned table is readable and writable only by its owner;
--   * the leaderboard is exposed through a view that leaks nothing beyond
--     username, avatar and weekly XP.

alter table public.profiles           enable row level security;
alter table public.subjects           enable row level security;
alter table public.topics             enable row level security;
alter table public.questions          enable row level security;
alter table public.app_content        enable row level security;
alter table public.daily_quests       enable row level security;
alter table public.achievements       enable row level security;
alter table public.study_sessions     enable row level security;
alter table public.question_attempts  enable row level security;
alter table public.daily_progress     enable row level security;
alter table public.user_daily_quests  enable row level security;
alter table public.weekly_xp          enable row level security;
alter table public.user_achievements  enable row level security;
alter table public.subscriptions      enable row level security;

-- ------------------------------------------------------- public content
drop policy if exists subjects_read on public.subjects;
create policy subjects_read on public.subjects
  for select using (true);

drop policy if exists topics_read on public.topics;
create policy topics_read on public.topics
  for select using (true);

-- Only active questions are readable, and only by signed-in users or the anon
-- key used by the app. No insert/update/delete policy exists, so normal users
-- can never modify the question bank.
drop policy if exists questions_read on public.questions;
create policy questions_read on public.questions
  for select using (is_active);

drop policy if exists app_content_read on public.app_content;
create policy app_content_read on public.app_content
  for select using (is_active);

drop policy if exists daily_quests_read on public.daily_quests;
create policy daily_quests_read on public.daily_quests
  for select using (is_active);

drop policy if exists achievements_read on public.achievements;
create policy achievements_read on public.achievements
  for select using (true);

-- ------------------------------------------------------- profiles
-- A profile is readable by its owner. Public leaderboard data goes through the
-- `weekly_leaderboard` view instead, so nothing else about a profile leaks.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own on public.profiles
  for delete using (auth.uid() = id);

-- ------------------------------------------------------- user-owned data
do $$
declare
  t text;
begin
  foreach t in array array[
    'study_sessions',
    'question_attempts',
    'daily_progress',
    'user_daily_quests',
    'weekly_xp',
    'user_achievements',
    'subscriptions'
  ]
  loop
    execute format('drop policy if exists %I_select_own on public.%I;', t, t);
    execute format(
      'create policy %I_select_own on public.%I for select using (auth.uid() = user_id);',
      t, t
    );

    execute format('drop policy if exists %I_insert_own on public.%I;', t, t);
    execute format(
      'create policy %I_insert_own on public.%I for insert with check (auth.uid() = user_id);',
      t, t
    );

    execute format('drop policy if exists %I_update_own on public.%I;', t, t);
    execute format(
      'create policy %I_update_own on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id);',
      t, t
    );

    execute format('drop policy if exists %I_delete_own on public.%I;', t, t);
    execute format(
      'create policy %I_delete_own on public.%I for delete using (auth.uid() = user_id);',
      t, t
    );
  end loop;
end $$;
