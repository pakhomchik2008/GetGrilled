-- Optional job-posting context (pasted PDF text or a fetched job-link's text) the candidate
-- can attach at Setup, so the interviewer tailors questions to the actual role. Same "tone/
-- domain only, not a source of real questions" guardrail as prep_plans.company_context —
-- enforced in the prompt (lib/roundPrompts.ts), not in the schema.
alter table public.interview_sessions
  add column job_context text;
