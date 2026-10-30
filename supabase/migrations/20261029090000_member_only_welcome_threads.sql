begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
alter table public.thread_balances alter column available_threads set default 0;

-- New guests start at zero. Existing earned and purchased balances are preserved.
create or replace function public.seed_new_user_thread_balance()
returns trigger language plpgsql security definer set search_path = public as $$
declare inserted_count integer;
begin
  insert into public.thread_balances(user_id, available_threads) values (new.id, 0)
    on conflict (user_id) do nothing;
  if new.is_guest or not exists (
    select 1 from auth.users identity where identity.id = new.id and not identity.is_anonymous
  ) then return new; end if;
  if tg_op = 'UPDATE' then
    if not old.is_guest then return new; end if;
  end if;
  if exists (select 1 from public.thread_ledger_entries where user_id = new.id and reason = 'welcome_grant') then
    return new;
  end if;
  insert into public.thread_ledger_entries(user_id, idempotency_key, amount, reason)
    values (new.id, new.id, 3, 'welcome_grant')
    on conflict do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count = 1 then
    update public.thread_balances set available_threads = available_threads + 3, updated_at = now()
      where user_id = new.id;
  end if;
  return new;
end; $$;

create trigger seed_member_welcome_on_account_link
  after update of is_guest on public.users
  for each row when (old.is_guest and not new.is_guest)
  execute function public.seed_new_user_thread_balance();

-- Older servers and app versions cannot redeem the retired guest offer.
create or replace function public.complete_guest_welcome_claim(p_user_id uuid)
returns table(available_threads integer)
language plpgsql security definer set search_path = public as $$
begin
  perform 1 from public.users profile join auth.users identity on identity.id = profile.id
    where profile.id = p_user_id and profile.is_guest and identity.is_anonymous
    for update of profile;
  if not found then raise exception 'Guest user was not found' using errcode = 'P0002'; end if;
  update public.guest_welcome_claims set status = 'denied', updated_at = now()
    where user_id = p_user_id and status in ('pending', 'eligible');
  return query select balance.available_threads from public.thread_balances balance where balance.user_id = p_user_id;
end; $$;

create or replace function public.complete_guest_welcome_claim(p_user_id uuid, p_lease_id uuid)
returns table(available_threads integer)
language sql security definer set search_path = public as $$
  select * from public.complete_guest_welcome_claim(p_user_id);
$$;

revoke all on function public.seed_new_user_thread_balance() from public, anon, authenticated;
revoke all on function public.complete_guest_welcome_claim(uuid) from public, anon, authenticated;
grant execute on function public.complete_guest_welcome_claim(uuid) to service_role;
revoke all on function public.complete_guest_welcome_claim(uuid,uuid) from public, anon, authenticated;
grant execute on function public.complete_guest_welcome_claim(uuid,uuid) to service_role;
commit;
