-- v2: round-based sessions (intro/technical/behavioral), test/competition
-- modes, and prep plans. See docs/v2-technical-spec.md for the full design.
--
-- Non-destructive: existing interview_sessions/session_feedback rows from
-- v1 (single-question sessions) are left as-is and stay readable in History
-- as legacy rows. New sessions use session_rounds instead of writing
-- question_text/transcript directly onto interview_sessions.

alter table public.interview_sessions
  add column mode text check (mode in ('test', 'competition')),
  add column role_title text,
  add column seniority text check (seniority in ('junior', 'mid', 'senior')),
  add column focus_notes text;

create table public.prep_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  role_title text not null,
  seniority text not null check (seniority in ('junior', 'mid', 'senior')),
  -- Context for tone only — never a source of real questions for this company.
  -- Enforced in the system prompt built for /api/plans/generate, not just here.
  company_context text,
  focus_notes text,
  created_at timestamptz not null default now()
);

create table public.plan_stages (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.prep_plans(id) on delete cascade,
  stage_order int not null,
  title text not null,
  focus_description text not null,
  status text not null default 'pending' check (status in ('pending', 'completed')),
  session_id uuid references public.interview_sessions(id) on delete set null
);

alter table public.interview_sessions
  add column plan_stage_id uuid references public.plan_stages(id) on delete set null;

create table public.session_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.interview_sessions(id) on delete cascade,
  round_type text not null check (round_type in ('intro', 'technical', 'behavioral')),
  round_order int not null,
  transcript jsonb not null default '[]'::jsonb,
  self_eval text check (self_eval in ('rough', 'ok', 'strong')),
  feedback_status text check (feedback_status in ('strong', 'good', 'needs_work')),
  feedback_notes text,
  status text not null default 'pending'
    check (status in ('pending', 'in_progress', 'completed', 'skipped')),
  started_at timestamptz,
  completed_at timestamptz,
  unique (session_id, round_order)
);

create index plan_stages_plan_id_idx on public.plan_stages(plan_id);
create index prep_plans_user_id_idx on public.prep_plans(user_id);
create index session_rounds_session_id_idx on public.session_rounds(session_id);
create index interview_sessions_mode_idx on public.interview_sessions(mode);

alter table public.prep_plans enable row level security;
alter table public.plan_stages enable row level security;
alter table public.session_rounds enable row level security;

create policy "users read own plans" on public.prep_plans
  for select using (auth.uid() = user_id);

create policy "users read own plan stages" on public.plan_stages
  for select using (
    auth.uid() = (select user_id from public.prep_plans where id = plan_stages.plan_id)
  );

create policy "users read own session rounds" on public.session_rounds
  for select using (
    auth.uid() = (select user_id from public.interview_sessions where id = session_rounds.session_id)
  );
