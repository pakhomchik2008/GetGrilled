-- Persist the session-level summary session/finish already generates — previously only
-- returned in the HTTP response, never saved, so History had nothing to show for past
-- sessions beyond the per-round rows.
alter table public.interview_sessions
  add column overall_summary text;
