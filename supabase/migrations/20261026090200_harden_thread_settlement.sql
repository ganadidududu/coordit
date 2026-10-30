begin;

alter table public.thread_balances
  add column if not exists refund_debt_threads integer not null default 0
    check (refund_debt_threads >= 0);

create or replace function public.repay_thread_refund_debt()
returns trigger language plpgsql set search_path = public as $$
declare repayment integer;
begin
  if new.available_threads > old.available_threads
    and new.refund_debt_threads = old.refund_debt_threads then
    repayment := least(new.available_threads - old.available_threads, old.refund_debt_threads);
    new.available_threads := new.available_threads - repayment;
    new.refund_debt_threads := old.refund_debt_threads - repayment;
  end if;
  return new;
end;
$$;
drop trigger if exists repay_thread_refund_debt on public.thread_balances;
create trigger repay_thread_refund_debt before update on public.thread_balances
  for each row execute function public.repay_thread_refund_debt();

-- Keep provider identifiers after account deletion so purchases and ad rewards cannot replay.
alter table public.apple_iap_transactions alter column user_id drop not null;
alter table public.apple_iap_transactions drop constraint if exists apple_iap_transactions_user_id_fkey;
alter table public.apple_iap_transactions add constraint apple_iap_transactions_user_id_fkey
  foreign key (user_id) references public.users(id) on delete set null;
alter table public.apple_iap_transactions drop constraint if exists apple_iap_transactions_check;
do $$ declare constraint_name text;
begin
  for constraint_name in select c.conname from pg_constraint c
    where c.conrelid = 'public.apple_iap_transactions'::regclass
      and c.contype = 'c' and pg_get_constraintdef(c.oid) = 'CHECK ((app_account_token = user_id))'
  loop
    execute format('alter table public.apple_iap_transactions drop constraint %I', constraint_name);
  end loop;
end $$;
alter table public.admob_reward_attempts alter column user_id drop not null;
alter table public.admob_reward_attempts drop constraint if exists admob_reward_attempts_user_id_fkey;
alter table public.admob_reward_attempts add constraint admob_reward_attempts_user_id_fkey
  foreign key (user_id) references public.users(id) on delete set null;
alter table public.admob_reward_attempts add column if not exists original_user_id uuid;
update public.admob_reward_attempts set original_user_id = user_id where original_user_id is null;
alter table public.admob_reward_attempts alter column original_user_id set not null;

create or replace function public.create_admob_reward_attempt(p_user_id uuid)
returns table(id uuid, status text, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  return query insert into public.admob_reward_attempts(user_id, original_user_id)
    values (p_user_id, p_user_id)
    returning admob_reward_attempts.id, admob_reward_attempts.status, admob_reward_attempts.expires_at;
end;
$$;

create table if not exists public.apple_iap_revocations (
  transaction_id text primary key,
  original_transaction_id text not null,
  product_id text not null,
  app_account_token uuid not null,
  purchased_at timestamptz not null,
  environment text not null check (environment in ('Production', 'Sandbox')),
  revoked_at timestamptz not null,
  processed_at timestamptz not null default now()
);
alter table public.apple_iap_revocations enable row level security;
alter table public.apple_iap_notification_receipts add column if not exists provider_transaction_id text;

alter table public.thread_ledger_entries drop constraint if exists thread_ledger_entries_reason_check;
alter table public.thread_ledger_entries add constraint thread_ledger_entries_reason_check
  check (reason in ('fit_analysis', 'fit_report', 'iap_purchase', 'iap_refund', 'ad_reward', 'admin_adjustment', 'welcome_grant'));

create or replace function public.grant_apple_iap_threads(
  p_user_id uuid, p_transaction_id text, p_original_transaction_id text,
  p_product_id text, p_app_account_token uuid, p_purchased_at timestamptz,
  p_environment text, p_thread_amount integer
)
returns table(available_threads integer, status text)
language plpgsql security definer set search_path = public as $$
declare
  existing_transaction public.apple_iap_transactions%rowtype;
  current_balance integer;
  transaction_row_id uuid;
  expected_amount integer;
begin
  expected_amount := case p_product_id when 'com.inseong.coordit.thread.5' then 5
    when 'com.inseong.coordit.thread.10' then 10 when 'com.inseong.coordit.thread.20' then 20 else null end;
  if expected_amount is null or p_thread_amount is distinct from expected_amount then
    raise exception using errcode = '22023', message = 'apple_product_amount_invalid';
  end if;
  if p_transaction_id is null or btrim(p_transaction_id) = ''
    or p_original_transaction_id is null or btrim(p_original_transaction_id) = ''
    or p_purchased_at is null or p_environment is null or p_environment not in ('Production', 'Sandbox') then
    raise exception using errcode = '22023', message = 'apple_transaction_invalid';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('apple-iap:' || p_transaction_id, 0));
  if exists (select 1 from public.apple_iap_revocations r where r.transaction_id = p_transaction_id) then
    raise exception using errcode = '23505', message = 'apple_transaction_revoked';
  end if;
  select t.* into existing_transaction from public.apple_iap_transactions t
    where t.transaction_id = p_transaction_id;
  if found then
    if existing_transaction.user_id is null or existing_transaction.user_id is distinct from p_user_id
      or existing_transaction.original_transaction_id is distinct from p_original_transaction_id
      or existing_transaction.product_id is distinct from p_product_id
      or existing_transaction.app_account_token is distinct from p_app_account_token
      or existing_transaction.purchased_at is distinct from p_purchased_at
      or existing_transaction.environment is distinct from p_environment
      or p_thread_amount is distinct from (case p_product_id
        when 'com.inseong.coordit.thread.5' then 5 when 'com.inseong.coordit.thread.10' then 10
        when 'com.inseong.coordit.thread.20' then 20 else null end) then
      raise exception using errcode = '23505', message = 'apple_transaction_metadata_conflict';
    end if;
    return query select b.available_threads, 'already_credited'::text
      from public.thread_balances b where b.user_id = p_user_id;
    return;
  end if;
  if p_app_account_token is distinct from p_user_id and not exists (
    select 1 from public.guest_account_merges m
    where m.guest_user_id = p_app_account_token and m.member_user_id = p_user_id
  ) then
    raise exception using errcode = '42501', message = 'apple_transaction_account_mismatch';
  end if;
  insert into public.thread_balances(user_id) values (p_user_id) on conflict (user_id) do nothing;
  select b.available_threads into current_balance from public.thread_balances b where b.user_id = p_user_id for update;
  insert into public.apple_iap_transactions(
    transaction_id, original_transaction_id, user_id, product_id, app_account_token, purchased_at, environment)
    values (p_transaction_id, p_original_transaction_id, p_user_id, p_product_id,
      p_app_account_token, p_purchased_at, p_environment) returning id into transaction_row_id;
  update public.thread_balances b set available_threads = b.available_threads + expected_amount, updated_at = now()
    where b.user_id = p_user_id returning b.available_threads into current_balance;
  insert into public.thread_ledger_entries(user_id, idempotency_key, amount, reason, apple_iap_transaction_id)
    values (p_user_id, transaction_row_id, expected_amount, 'iap_purchase', transaction_row_id);
  return query select current_balance, 'credited'::text;
end;
$$;

create or replace function public.revoke_apple_iap_threads(
  p_notification_uuid uuid, p_notification_type text, p_subtype text,
  p_environment text, p_transaction_id text, p_original_transaction_id text,
  p_product_id text, p_app_account_token uuid, p_purchased_at timestamptz,
  p_revoked_at timestamptz
)
returns table(available_threads integer, status text)
language plpgsql security definer set search_path = public as $$
declare
  purchase public.apple_iap_transactions%rowtype;
  revocation public.apple_iap_revocations%rowtype;
  receipt public.apple_iap_notification_receipts%rowtype;
  current_balance integer := 0;
  thread_amount integer;
  was_revoked boolean;
begin
  if p_notification_type not in ('REFUND', 'REVOKE') or p_notification_type is null
    or p_environment not in ('Production', 'Sandbox') or p_environment is null
    or p_transaction_id is null or btrim(p_transaction_id) = ''
    or p_original_transaction_id is null or btrim(p_original_transaction_id) = ''
    or p_app_account_token is null or p_purchased_at is null or p_revoked_at is null then
    raise exception using errcode = '22023', message = 'apple_revocation_invalid';
  end if;
  thread_amount := case p_product_id when 'com.inseong.coordit.thread.5' then 5
    when 'com.inseong.coordit.thread.10' then 10 when 'com.inseong.coordit.thread.20' then 20 else null end;
  if thread_amount is null then
    raise exception using errcode = '22023', message = 'apple_product_amount_invalid';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('apple-iap:' || p_transaction_id, 0));
  select t.* into purchase from public.apple_iap_transactions t where t.transaction_id = p_transaction_id;
  if found and (purchase.original_transaction_id is distinct from p_original_transaction_id
    or purchase.product_id is distinct from p_product_id
    or purchase.app_account_token is distinct from p_app_account_token
    or purchase.purchased_at is distinct from p_purchased_at
    or purchase.environment is distinct from p_environment) then
    raise exception using errcode = '23505', message = 'apple_transaction_metadata_conflict';
  end if;
  select r.* into revocation from public.apple_iap_revocations r where r.transaction_id = p_transaction_id;
  was_revoked := found;
  if was_revoked and (revocation.original_transaction_id is distinct from p_original_transaction_id
    or revocation.product_id is distinct from p_product_id
    or revocation.app_account_token is distinct from p_app_account_token
    or revocation.purchased_at is distinct from p_purchased_at
    or revocation.environment is distinct from p_environment
    or revocation.revoked_at is distinct from p_revoked_at) then
    raise exception using errcode = '23505', message = 'apple_revocation_metadata_conflict';
  end if;
  if not was_revoked then
    insert into public.apple_iap_revocations values (
      p_transaction_id, p_original_transaction_id, p_product_id, p_app_account_token,
      p_purchased_at, p_environment, p_revoked_at, now());
    if purchase.user_id is not null then
      select b.available_threads into current_balance from public.thread_balances b
        where b.user_id = purchase.user_id for update;
      update public.thread_balances b
        set available_threads = greatest(0, b.available_threads - thread_amount),
          refund_debt_threads = b.refund_debt_threads + greatest(0, thread_amount - b.available_threads),
          updated_at = now()
        where b.user_id = purchase.user_id returning b.available_threads into current_balance;
      insert into public.thread_ledger_entries(user_id, idempotency_key, amount, reason)
        values (purchase.user_id, purchase.id, -thread_amount, 'iap_refund');
    end if;
  elsif purchase.user_id is not null then
    select b.available_threads into current_balance from public.thread_balances b where b.user_id = purchase.user_id;
  end if;
  insert into public.apple_iap_notification_receipts(
    notification_uuid, notification_type, subtype, environment, apple_iap_transaction_id, provider_transaction_id)
    values (p_notification_uuid, p_notification_type, p_subtype, p_environment, purchase.id, p_transaction_id)
    on conflict (notification_uuid) do nothing;
  select r.* into receipt from public.apple_iap_notification_receipts r where r.notification_uuid = p_notification_uuid;
  if receipt.notification_type is distinct from p_notification_type or receipt.subtype is distinct from p_subtype
    or receipt.environment is distinct from p_environment
    or receipt.provider_transaction_id is distinct from p_transaction_id then
    raise exception using errcode = '23505', message = 'apple_notification_metadata_conflict';
  end if;
  return query select coalesce(current_balance, 0), case when was_revoked then 'already_revoked' else 'revoked' end;
end;
$$;

create or replace function public.consume_fit_report_thread(
  p_user_id uuid, p_idempotency_key uuid, p_fit_analysis_result_id uuid
)
returns table(available_threads integer, status text)
language plpgsql security definer set search_path = public as $$
declare current_balance integer; existing_result_id uuid;
begin
  if not exists (select 1 from public.fit_analysis_results r
    where r.id = p_fit_analysis_result_id and r.user_id = p_user_id) then
    raise exception using errcode = '42501', message = 'fit_result_ownership_required';
  end if;
  insert into public.thread_balances(user_id) values (p_user_id) on conflict (user_id) do nothing;
  select b.available_threads into current_balance from public.thread_balances b where b.user_id = p_user_id for update;
  select e.fit_analysis_result_id into existing_result_id from public.thread_ledger_entries e
    where e.user_id = p_user_id and e.idempotency_key = p_idempotency_key and e.reason = 'fit_report';
  if found then
    if existing_result_id is distinct from p_fit_analysis_result_id then
      raise exception using errcode = '23505', message = 'thread_idempotency_conflict';
    end if;
    return query select current_balance, 'already_consumed'::text;
    return;
  end if;
  if current_balance <= 0 then
    return query select current_balance, 'insufficient'::text;
    return;
  end if;
  update public.thread_balances b set available_threads = b.available_threads - 1, updated_at = now()
    where b.user_id = p_user_id returning b.available_threads into current_balance;
  insert into public.thread_ledger_entries(user_id, idempotency_key, fit_analysis_result_id, amount, reason)
    values (p_user_id, p_idempotency_key, p_fit_analysis_result_id, -1, 'fit_report');
  return query select current_balance, 'consumed'::text;
end;
$$;

do $$ begin
  if to_regprocedure('public.grant_admob_reward_verified_attempt(uuid,text)') is null then
    alter function public.grant_admob_reward(uuid,text) rename to grant_admob_reward_verified_attempt;
  end if;
end $$;

create or replace function public.grant_admob_reward(
  p_attempt_id uuid, p_transaction_id text, p_signed_user_id text
)
returns table(available_threads integer, status text)
language plpgsql security definer set search_path = public as $$
declare attempt public.admob_reward_attempts%rowtype;
begin
  select a.* into attempt from public.admob_reward_attempts a where a.id = p_attempt_id for update;
  if not found or attempt.user_id is null then
    return query select 0, 'unknown_attempt'::text;
    return;
  end if;
  if p_signed_user_id is null or lower(p_signed_user_id) is distinct from attempt.original_user_id::text then
    raise exception using errcode = '42501', message = 'admob_callback_account_mismatch';
  end if;
  return query select * from public.grant_admob_reward_verified_attempt(p_attempt_id, p_transaction_id);
end;
$$;

-- A client must not forge an analysis result or change a persisted paid report.
revoke insert, update, delete, truncate, references, trigger on public.fit_analysis_results from public, anon, authenticated;
grant select on public.fit_analysis_results to authenticated;
revoke all on public.thread_balances, public.thread_ledger_entries, public.apple_iap_transactions,
  public.apple_iap_notification_receipts, public.apple_iap_revocations,
  public.admob_reward_attempts, public.admob_reward_transactions from public, anon, authenticated;

do $$ declare fn regprocedure;
begin
  for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'get_thread_balance', 'consume_fit_analysis_thread', 'create_fit_analysis_result_and_consume_thread',
      'consume_fit_report_thread', 'grant_apple_iap_threads', 'reconcile_apple_iap_notification',
      'record_apple_iap_notification', 'create_admob_reward_attempt', 'grant_admob_reward', 'revoke_apple_iap_threads')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end $$;
revoke all on function public.repay_thread_refund_debt() from public, anon, authenticated, service_role;
revoke all on function public.grant_admob_reward_verified_attempt(uuid,text) from public, anon, authenticated, service_role;

commit;
