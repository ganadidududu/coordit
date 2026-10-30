create or replace function public.complete_camera_comparison(
  p_user_id uuid,
  p_idempotency_key uuid,
  p_fit_analysis_result_id uuid,
  p_report_artifact jsonb
)
returns table(available_threads integer, status text, stored_report jsonb)
language plpgsql security definer set search_path = public
as $$
declare
  current_balance integer;
  existing_result_id uuid;
  current_details jsonb;
begin
  if not exists (select 1 from public.fit_analysis_results r where r.id = p_fit_analysis_result_id and r.user_id = p_user_id) then
    raise exception using errcode = '42501', message = 'fit_result_ownership_required';
  end if;
  if jsonb_typeof(p_report_artifact) is distinct from 'object'
    or p_report_artifact->>'schemaVersion' is distinct from '1'
    or jsonb_typeof(p_report_artifact->'report') is distinct from 'object'
    or jsonb_typeof(p_report_artifact->'chartData') is distinct from 'object' then
    raise exception using errcode = '22023', message = 'valid_camera_report_required';
  end if;
  insert into public.thread_balances(user_id) values (p_user_id) on conflict (user_id) do nothing;
  select b.available_threads into current_balance from public.thread_balances b where b.user_id = p_user_id for update;
  select r.result_details into current_details from public.fit_analysis_results r
    where r.id = p_fit_analysis_result_id and r.user_id = p_user_id for update;
  select e.fit_analysis_result_id into existing_result_id from public.thread_ledger_entries e
    where e.user_id = p_user_id and e.idempotency_key = p_idempotency_key and e.reason = 'fit_report';
  if found and existing_result_id is distinct from p_fit_analysis_result_id then
    raise exception using errcode = '23505', message = 'thread_idempotency_conflict';
  end if;
  if exists (select 1 from public.thread_ledger_entries e where e.user_id = p_user_id
    and e.fit_analysis_result_id = p_fit_analysis_result_id and e.reason in ('fit_analysis', 'fit_report') and e.amount = -1) then
    if current_details->'storedFitReport' is null then
      update public.fit_analysis_results set result_details = coalesce(current_details, '{}'::jsonb) || jsonb_build_object('storedFitReport', p_report_artifact)
        where id = p_fit_analysis_result_id and user_id = p_user_id;
    end if;
    return query select current_balance, 'already_consumed'::text, coalesce(current_details->'storedFitReport', p_report_artifact);
    return;
  end if;
  if current_balance <= 0 then
    return query select current_balance, 'insufficient'::text, null::jsonb;
    return;
  end if;
  update public.fit_analysis_results set result_details = coalesce(current_details, '{}'::jsonb) || jsonb_build_object('storedFitReport', p_report_artifact)
    where id = p_fit_analysis_result_id and user_id = p_user_id;
  update public.thread_balances b set available_threads = b.available_threads - 1, updated_at = now()
    where b.user_id = p_user_id returning b.available_threads into current_balance;
  insert into public.thread_ledger_entries(user_id, idempotency_key, fit_analysis_result_id, amount, reason)
    values (p_user_id, p_idempotency_key, p_fit_analysis_result_id, -1, 'fit_report');
  return query select current_balance, 'consumed'::text, p_report_artifact;
end;
$$;

revoke all on function public.complete_camera_comparison(uuid, uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.complete_camera_comparison(uuid, uuid, uuid, jsonb) to service_role;
