-- Initial schema: users, interview sessions, session feedback.
-- Auth identity lives in Supabase's built-in auth.users; this table holds
-- app-specific profile fields keyed to that same id.

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  subscription_status text not null default 'free'
    check (subscription_status in ('free', 'paid')),
  created_at timestamptz not null default now()
);

create table public.interview_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
  topic text,
  status text not null default 'started'
    check (status in ('started', 'in_progress', 'awaiting_feedback', 'completed')),
  question_text text,
  transcript jsonb not null default '[]'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create table public.session_feedback (
  session_id uuid primary key references public.interview_sessions(id) on delete cascade,
  correctness_score int not null check (correctness_score between 0 and 100),
  correctness_notes text not null,
  communication_score int not null check (communication_score between 0 and 100),
  communication_notes text not null,
  efficiency_score int not null check (efficiency_score between 0 and 100),
  efficiency_notes text not null,
  overall_summary text not null,
  created_at timestamptz not null default now()
);

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  session_id uuid references public.interview_sessions(id) on delete set null,
  event_type text not null check (event_type in ('session_started', 'session_completed')),
  created_at timestamptz not null default now()
);

create index interview_sessions_user_id_idx on public.interview_sessions(user_id);
create index interview_sessions_status_idx on public.interview_sessions(status);
create index analytics_events_user_id_idx on public.analytics_events(user_id);

-- RLS: users only ever read their own rows. All writes to session status/
-- feedback happen from Vercel via the service role key, which bypasses RLS.
alter table public.users enable row level security;
alter table public.interview_sessions enable row level security;
alter table public.session_feedback enable row level security;
alter table public.analytics_events enable row level security;

create policy "users read own row" on public.users
  for select using (auth.uid() = id);

create policy "users read own sessions" on public.interview_sessions
  for select using (auth.uid() = user_id);

create policy "users read own feedback" on public.session_feedback
  for select using (
    auth.uid() = (
      select user_id from public.interview_sessions
      where id = session_feedback.session_id
    )
  );
