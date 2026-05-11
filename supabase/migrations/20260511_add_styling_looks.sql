create table public.styling_looks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  name_ko text not null,
  mood text not null default '',
  palette jsonb not null default '[]'::jsonb,
  ai_reasoning text not null default '',
  fit_score numeric(5,2),
  item_ids jsonb not null default '[]'::jsonb,
  prompt text not null default '',
  created_at timestamptz not null default now()
);

create index styling_looks_user_id_idx on public.styling_looks(user_id);
