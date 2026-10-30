begin;
create table public.guest_account_merges (
  guest_user_id uuid primary key,
  member_user_id uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.guest_account_merges enable row level security;
revoke all on table public.guest_account_merges from public, anon, authenticated;
grant all on table public.guest_account_merges to service_role;

create function public.prevent_merged_guest_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.guest_account_merges where guest_user_id = new.id) then
    raise exception 'Guest account has already been merged' using errcode = '42501';
  end if;
  return new;
end; $$;
create trigger prevent_merged_guest_profile before insert or update on public.users
  for each row execute function public.prevent_merged_guest_profile();
revoke all on function public.prevent_merged_guest_profile() from public, anon, authenticated;

create or replace function public.merge_guest_account(p_guest_user_id uuid, p_member_user_id uuid)
returns table(available_threads integer)
language plpgsql security definer set search_path = public as $$
declare
  target_table text;
  total_balance bigint;
  total_debt bigint;
  merged_balance integer;
begin
  if p_guest_user_id = p_member_user_id then
    raise exception 'Guest and member users must differ' using errcode = '22023';
  end if;
  perform 1 from public.users where id in (p_guest_user_id, p_member_user_id)
    order by id for update;
  if exists (select 1 from public.guest_account_merges
    where guest_user_id = p_guest_user_id and member_user_id = p_member_user_id) then
    return query select balance.available_threads from public.thread_balances balance
      where balance.user_id = p_member_user_id;
    return;
  end if;
  if not exists (select 1 from public.users profile join auth.users identity on profile.id = identity.id
    where profile.id = p_guest_user_id and profile.is_guest and identity.is_anonymous) then
    raise exception 'Guest user was not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.users profile join auth.users identity on profile.id = identity.id
    where profile.id = p_member_user_id and not profile.is_guest and not identity.is_anonymous) then
    raise exception 'Member user was not found' using errcode = 'P0002';
  end if;

  insert into public.thread_balances(user_id, available_threads) values (p_member_user_id, 0)
    on conflict (user_id) do nothing;
  perform 1 from public.thread_balances where user_id in (p_guest_user_id, p_member_user_id)
    order by user_id for update;

  insert into public.guest_account_merges(guest_user_id, member_user_id)
    values (p_guest_user_id, p_member_user_id);
  update public.apple_iap_transactions set user_id = p_member_user_id where user_id = p_guest_user_id;
  update public.admob_reward_attempts set user_id = p_member_user_id where user_id = p_guest_user_id;

  delete from public.user_consents guest_consent using public.user_consents member_consent
    where guest_consent.user_id = p_guest_user_id and member_consent.user_id = p_member_user_id
      and guest_consent.consent_key = member_consent.consent_key
      and guest_consent.consent_version = member_consent.consent_version;
  foreach target_table in array array[
    'user_consents', 'body_measurements', 'clothing_items', 'clothing_sizes',
    'reference_clothing', 'external_products', 'product_import_logs', 'external_product_sizes',
    'fit_analysis_results', 'clothing_fit_assessments', 'user_feedback', 'recommendation_logs', 'styling_looks'
  ] loop
    execute format('update public.%I set user_id = $1 where user_id = $2', target_table)
      using p_member_user_id, p_guest_user_id;
  end loop;
  delete from public.clothing_item_save_requests guest_request using public.clothing_item_save_requests member_request
    where guest_request.user_id = p_guest_user_id and member_request.user_id = p_member_user_id
      and guest_request.idempotency_key = member_request.idempotency_key;
  update public.clothing_item_save_requests set user_id = p_member_user_id where user_id = p_guest_user_id;
  delete from public.thread_ledger_entries guest_entry using public.thread_ledger_entries member_entry
    where guest_entry.user_id = p_guest_user_id and member_entry.user_id = p_member_user_id
      and guest_entry.idempotency_key = member_entry.idempotency_key and guest_entry.reason = member_entry.reason;
  update public.thread_ledger_entries set user_id = p_member_user_id where user_id = p_guest_user_id;

  select coalesce(sum(balance.available_threads), 0), coalesce(sum(balance.refund_debt_threads), 0)
    into total_balance, total_debt from public.thread_balances balance
    where balance.user_id in (p_guest_user_id, p_member_user_id);
  update public.thread_balances set available_threads = greatest(0, total_balance - total_debt)::integer,
    refund_debt_threads = greatest(0, total_debt - total_balance)::integer, updated_at = now()
    where user_id = p_member_user_id returning thread_balances.available_threads into merged_balance;
  delete from public.thread_balances where user_id = p_guest_user_id;
  delete from public.guest_welcome_claims where user_id = p_guest_user_id;
  delete from public.users where id = p_guest_user_id;
  return query select merged_balance;
end; $$;

revoke all on function public.merge_guest_account(uuid,uuid) from public, anon, authenticated;
grant execute on function public.merge_guest_account(uuid,uuid) to service_role;
commit;
