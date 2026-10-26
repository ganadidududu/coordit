begin;

create function public.assert_thread_purchase_member(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from public.users profile join auth.users identity on identity.id = profile.id
    where profile.id = p_user_id and profile.is_guest = false and identity.is_anonymous = false
    for share of profile, identity;
  if not found then
    raise exception using errcode = '42501', message = 'thread_purchase_account_link_required';
  end if;
end; $$;

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
  perform public.assert_thread_purchase_member(p_user_id);
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

revoke all on function public.assert_thread_purchase_member(uuid) from public, anon, authenticated;
grant execute on function public.assert_thread_purchase_member(uuid) to service_role;
revoke all on function public.grant_apple_iap_threads(uuid,text,text,text,uuid,timestamptz,text,integer)
  from public, anon, authenticated;
grant execute on function public.grant_apple_iap_threads(uuid,text,text,text,uuid,timestamptz,text,integer) to service_role;
commit;
