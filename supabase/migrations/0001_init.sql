-- YKS Level — initial schema.
-- All day/week columns are plain `date` values already normalised to
-- Europe/Istanbul by the client (see lib/core/utils/tr_date.dart). Timestamps
-- are timestamptz.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------- enums
do $$ begin
  create type exam_type as enum ('TYT', 'AYT');
exception when duplicate_object then null; end $$;

do $$ begin
  create type question_difficulty as enum ('easy', 'medium', 'hard');
exception when duplicate_object then null; end $$;

do $$ begin
  create type premium_status as enum ('free', 'premium', 'grace_period', 'expired');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id                   uuid primary key references auth.users (id) on delete cascade,
  username             text not null default '',
  avatar_id            smallint not null default 0,
  total_xp             integer not null default 0 check (total_xp >= 0),
  current_streak       integer not null default 0 check (current_streak >= 0),
  longest_streak       integer not null default 0 check (longest_streak >= 0),
  last_active_date     date,
  preferred_exam_track text not null default 'Henüz seçmedim',
  premium_status       premium_status not null default 'free',
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists profiles_total_xp_idx on public.profiles (total_xp desc);

-- ---------------------------------------------------------------- content
create table if not exists public.subjects (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null,
  exam_type  exam_type not null default 'TYT',
  icon       text not null default 'school',
  color      text not null default '#4F6BFF',
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.topics (
  id         uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects (id) on delete cascade,
  code       text not null,
  name       text not null,
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  unique (subject_id, code)
);

create index if not exists topics_subject_idx on public.topics (subject_id);

create table if not exists public.questions (
  id                 uuid primary key default gen_random_uuid(),
  external_id        text unique,
  exam_type          exam_type not null default 'TYT',
  subject_id         uuid not null references public.subjects (id) on delete cascade,
  topic_id           uuid references public.topics (id) on delete set null,
  year               smallint,
  -- 'demo' for the bundled sample bank, 'licensed' for content you own the
  -- rights to. Official OSYM questions must never be imported. See
  -- docs/question_import.md.
  source_type        text not null default 'demo',
  question_text      text not null,
  question_image_url text,
  option_a           text not null,
  option_b           text not null,
  option_c           text not null,
  option_d           text not null,
  option_e           text,
  correct_option     char(1) not null check (correct_option in ('A','B','C','D','E')),
  explanation        text,
  difficulty         question_difficulty not null default 'medium',
  is_active          boolean not null default true,
  created_at         timestamptz not null default now()
);

create index if not exists questions_subject_idx on public.questions (subject_id) where is_active;
create index if not exists questions_topic_idx on public.questions (topic_id) where is_active;
create index if not exists questions_exam_type_idx on public.questions (exam_type) where is_active;

-- Daily facts and any other CMS-ish copy pulled at runtime.
create table if not exists public.app_content (
  id           uuid primary key default gen_random_uuid(),
  content_type text not null,
  subject_code text,
  title        text,
  body         text not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

create index if not exists app_content_type_idx on public.app_content (content_type) where is_active;

-- ---------------------------------------------------------------- gameplay
create table if not exists public.study_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  subject_code   text,
  topic_code     text,
  question_count integer not null default 0,
  correct_count  integer not null default 0,
  xp_earned      integer not null default 0,
  best_combo     integer not null default 0,
  duration_ms    integer not null default 0,
  source         text not null default 'topic',
  created_at     timestamptz not null default now()
);

create index if not exists study_sessions_user_idx
  on public.study_sessions (user_id, created_at desc);

create table if not exists public.question_attempts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  session_id       uuid references public.study_sessions (id) on delete cascade,
  question_id      text not null,
  selected_answer  char(1) not null,
  is_correct       boolean not null,
  response_time_ms integer not null default 0,
  xp_awarded       integer not null default 0,
  answered_at      timestamptz not null default now()
);

create index if not exists question_attempts_user_idx
  on public.question_attempts (user_id, answered_at desc);
create index if not exists question_attempts_question_idx
  on public.question_attempts (question_id);

create table if not exists public.daily_progress (
  user_id           uuid not null references auth.users (id) on delete cascade,
  day               date not null,
  questions_solved  integer not null default 0,
  questions_correct integer not null default 0,
  xp_earned         integer not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  primary key (user_id, day)
);

-- Catalogue of quests. The MVP ships a fixed set; the table exists so quests
-- can be rotated per date later without a client release.
create table if not exists public.daily_quests (
  code         text primary key,
  kind         text not null,
  target       integer not null default 1,
  xp_reward    integer not null default 0,
  subject_code text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

create table if not exists public.user_daily_quests (
  user_id      uuid not null references auth.users (id) on delete cascade,
  day          date not null,
  quest_code   text not null references public.daily_quests (code) on delete cascade,
  progress     integer not null default 0,
  completed_at timestamptz,
  primary key (user_id, day, quest_code)
);

create table if not exists public.weekly_xp (
  user_id    uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  xp         integer not null default 0 check (xp >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, week_start)
);

create index if not exists weekly_xp_leaderboard_idx
  on public.weekly_xp (week_start, xp desc);

create table if not exists public.achievements (
  code         text primary key,
  kind         text not null,
  threshold    integer not null default 1,
  icon         text not null default '🏅',
  subject_code text,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.user_achievements (
  user_id          uuid not null references auth.users (id) on delete cascade,
  achievement_code text not null references public.achievements (code) on delete cascade,
  unlocked_at      timestamptz not null default now(),
  primary key (user_id, achievement_code)
);

-- Mirror of the Play Billing entitlement. Written by the client today; the
-- columns are ready for server-side verification via the Play Developer API.
create table if not exists public.subscriptions (
  user_id          uuid primary key references auth.users (id) on delete cascade,
  product_id       text not null,
  status           premium_status not null default 'free',
  purchase_token   text,
  original_txn_id  text,
  expires_at       timestamptz,
  verified_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------- triggers
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists daily_progress_touch on public.daily_progress;
create trigger daily_progress_touch before update on public.daily_progress
  for each row execute function public.touch_updated_at();

drop trigger if exists weekly_xp_touch on public.weekly_xp;
create trigger weekly_xp_touch before update on public.weekly_xp
  for each row execute function public.touch_updated_at();

drop trigger if exists subscriptions_touch on public.subscriptions;
create trigger subscriptions_touch before update on public.subscriptions
  for each row execute function public.touch_updated_at();

-- Every new auth user gets a profile row so the client can upsert freely.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
