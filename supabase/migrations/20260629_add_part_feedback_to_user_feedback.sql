alter table public.user_feedback
  add column if not exists part_feedback jsonb not null default '{}'::jsonb;
