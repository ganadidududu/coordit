create table if not exists public.clothing_fit_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  clothing_item_id uuid not null references public.clothing_items(id) on delete cascade,
  clothing_size_id uuid references public.clothing_sizes(id) on delete set null,
  fit_score numeric(6,2) not null check (fit_score between 0 and 100),
  fit_label text not null,
  fit_comment text not null,
  recommendation_confidence text not null check (recommendation_confidence in ('high', 'medium', 'low')),
  weighted_fit_distance numeric(8,3) not null check (weighted_fit_distance >= 0),
  diffs jsonb not null default '{}'::jsonb,
  part_explanations jsonb not null default '[]'::jsonb,
  part_statuses jsonb not null default '{}'::jsonb,
  compared_measurement_count integer not null check (compared_measurement_count > 0),
  result_details jsonb not null default '{}'::jsonb,
  algorithm_version text not null,
  evaluated_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_clothing_fit_assessments_current
  on public.clothing_fit_assessments(user_id, clothing_item_id, evaluated_at desc, id desc);

alter table public.clothing_fit_assessments enable row level security;

create policy "clothing fit assessments owner read"
on public.clothing_fit_assessments for select to authenticated
using (auth.uid() = user_id);

create or replace function public.record_clothing_fit_assessment(
  p_user_id uuid,
  p_clothing_item_id uuid,
  p_clothing_size_id uuid,
  p_assessment jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_assessment public.clothing_fit_assessments%rowtype;
begin
  insert into public.clothing_fit_assessments (
    user_id, clothing_item_id, clothing_size_id, fit_score, fit_label,
    fit_comment, recommendation_confidence, weighted_fit_distance, diffs,
    part_explanations, part_statuses, compared_measurement_count,
    result_details, algorithm_version, evaluated_at
  )
  select
    p_user_id, item.id, size.id,
    (p_assessment ->> 'fit_score')::numeric,
    p_assessment ->> 'fit_label',
    p_assessment ->> 'fit_comment',
    p_assessment ->> 'recommendation_confidence',
    (p_assessment ->> 'weighted_fit_distance')::numeric,
    coalesce(p_assessment -> 'diffs', '{}'::jsonb),
    coalesce(p_assessment -> 'part_explanations', '[]'::jsonb),
    coalesce(p_assessment -> 'part_statuses', '{}'::jsonb),
    (p_assessment ->> 'compared_measurement_count')::integer,
    coalesce(p_assessment -> 'result_details', '{}'::jsonb),
    p_assessment ->> 'algorithm_version',
    (p_assessment ->> 'evaluated_at')::timestamptz
  from public.clothing_items item
  join public.clothing_sizes size
    on size.id = p_clothing_size_id
    and size.clothing_item_id = item.id
    and size.user_id = p_user_id
  where item.id = p_clothing_item_id
    and item.user_id = p_user_id
  returning * into v_assessment;

  if not found then
    raise exception 'Clothing item or size was not found' using errcode = 'P0002';
  end if;

  return to_jsonb(v_assessment);
end;
$$;

revoke all on table public.clothing_fit_assessments from anon, authenticated;
grant select on table public.clothing_fit_assessments to authenticated;
revoke all on function public.record_clothing_fit_assessment(uuid, uuid, uuid, jsonb)
from public, anon, authenticated;
grant execute on function public.record_clothing_fit_assessment(uuid, uuid, uuid, jsonb)
to service_role;
