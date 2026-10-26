begin;

-- All welcome credit must pass DeviceCheck, including social/email account creation.
alter table public.thread_balances alter column available_threads set default 0;
create or replace function public.seed_new_user_thread_balance()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.thread_balances(user_id, available_threads) values (new.id, 0)
  on conflict (user_id) do nothing;
  return new;
end; $$;

-- Preserve every existing balance. Legacy seeds are never topped up a second time.
alter table public.guest_welcome_claims drop constraint guest_welcome_claims_status_check;
alter table public.guest_welcome_claims add constraint guest_welcome_claims_status_check
  check (status in ('pending', 'eligible', 'granted', 'denied', 'legacy'));
insert into public.guest_welcome_claims(user_id, status)
select id, 'legacy' from public.users where is_guest
on conflict (user_id) do nothing;
update public.guest_welcome_claims set status = 'legacy', updated_at = now()
where status in ('pending', 'eligible');

-- DeviceCheck tokens are opaque and rotate, so serialization is global, not per token.
create table public.guest_welcome_gate (
  singleton boolean primary key default true check (singleton),
  lease_id uuid,
  user_id uuid,
  expires_at timestamptz not null default '-infinity'
);
insert into public.guest_welcome_gate(singleton) values (true);
alter table public.guest_welcome_gate enable row level security;
revoke all on table public.guest_welcome_gate from public, anon, authenticated;
grant all on table public.guest_welcome_gate to service_role;

drop function public.prepare_guest_welcome_claim(uuid);
drop function public.mark_guest_welcome_eligible(uuid);
drop function public.complete_guest_welcome_claim(uuid);
drop function public.deny_guest_welcome_claim(uuid);

create function public.prepare_guest_welcome_claim(p_user_id uuid, p_lease_id uuid)
returns table(status text)
language plpgsql security definer set search_path = public as $$
declare claim_status text;
begin
  if p_lease_id is null then raise exception 'Welcome lease is required'; end if;
  perform 1 from public.guest_welcome_gate where singleton for update;
  perform 1 from public.users profile join auth.users identity on identity.id = profile.id
    where profile.id = p_user_id and profile.is_guest and identity.is_anonymous
    for update of profile;
  if not found then raise exception 'Guest user was not found' using errcode = 'P0002'; end if;

  insert into public.guest_welcome_claims(user_id) values (p_user_id)
    on conflict (user_id) do nothing;
  select claim.status into claim_status from public.guest_welcome_claims claim
    where claim.user_id = p_user_id for update;
  if claim_status in ('granted', 'denied') then
    return query select claim_status;
    return;
  end if;

  if exists (select 1 from public.guest_welcome_gate where expires_at > clock_timestamp()) then
    raise exception 'Welcome verification is busy; retry shortly' using errcode = '55P03';
  end if;
  update public.guest_welcome_gate set lease_id = p_lease_id, user_id = p_user_id,
    expires_at = clock_timestamp() + interval '45 seconds' where singleton;
  -- An interrupted eligible attempt is never authority to bypass a fresh Apple query.
  claim_status := case when claim_status = 'legacy' then 'legacy' else 'pending' end;
  update public.guest_welcome_claims set status = claim_status, updated_at = now()
    where user_id = p_user_id;
  return query select claim_status;
end; $$;

create function public.assert_guest_welcome_lease(p_user_id uuid, p_lease_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from public.guest_welcome_gate where singleton for update;
  if not exists (select 1 from public.guest_welcome_gate
    where lease_id = p_lease_id and user_id = p_user_id and expires_at > clock_timestamp()) then
    raise exception 'Welcome verification expired; retry' using errcode = '55P03';
  end if;
end; $$;

create function public.mark_guest_welcome_eligible(p_user_id uuid, p_lease_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.assert_guest_welcome_lease(p_user_id, p_lease_id);
  update public.guest_welcome_claims set status = 'eligible', updated_at = now()
    where user_id = p_user_id and status = 'pending';
  if not found then raise exception 'Guest welcome claim is not pending'; end if;
end; $$;

create function public.complete_guest_welcome_claim(p_user_id uuid, p_lease_id uuid)
returns table(available_threads integer)
language plpgsql security definer set search_path = public as $$
declare inserted_count integer; claim_status text;
begin
  perform public.assert_guest_welcome_lease(p_user_id, p_lease_id);
  perform 1 from public.users where id = p_user_id and is_guest for update;
  if not found then raise exception 'Guest user was not found'; end if;
  select claim.status into claim_status from public.guest_welcome_claims claim
    where claim.user_id = p_user_id and claim.status in ('eligible', 'legacy') for update;
  if not found then raise exception 'Guest welcome claim is not eligible'; end if;
  insert into public.thread_balances(user_id, available_threads) values (p_user_id, 0)
    on conflict (user_id) do nothing;
  if claim_status = 'eligible' then
    insert into public.thread_ledger_entries(user_id, idempotency_key, amount, reason)
      values (p_user_id, p_user_id, 3, 'welcome_grant')
      on conflict (user_id, idempotency_key, reason) do nothing;
    get diagnostics inserted_count = row_count;
    if inserted_count = 1 then
      update public.thread_balances set available_threads = thread_balances.available_threads + 3,
        updated_at = now() where user_id = p_user_id;
    end if;
  end if;
  update public.guest_welcome_claims set status = 'granted', updated_at = now()
    where user_id = p_user_id;
  return query select balance.available_threads from public.thread_balances balance where balance.user_id = p_user_id;
end; $$;

create function public.deny_guest_welcome_claim(p_user_id uuid, p_lease_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.assert_guest_welcome_lease(p_user_id, p_lease_id);
  update public.guest_welcome_claims set status = 'denied', updated_at = now()
    where user_id = p_user_id and status in ('pending', 'eligible');
end; $$;

create function public.release_guest_welcome_lease(p_lease_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.guest_welcome_gate set lease_id = null, user_id = null, expires_at = '-infinity'
    where singleton and lease_id = p_lease_id;
end; $$;

-- Identity flags and wallet claims cannot be forged using the public Supabase API.
revoke update on table public.users from public, anon, authenticated;
revoke all on function public.prepare_guest_welcome_claim(uuid,uuid) from public, anon, authenticated;
revoke all on function public.assert_guest_welcome_lease(uuid,uuid) from public, anon, authenticated;
revoke all on function public.mark_guest_welcome_eligible(uuid,uuid) from public, anon, authenticated;
revoke all on function public.complete_guest_welcome_claim(uuid,uuid) from public, anon, authenticated;
revoke all on function public.deny_guest_welcome_claim(uuid,uuid) from public, anon, authenticated;
revoke all on function public.release_guest_welcome_lease(uuid) from public, anon, authenticated;
grant execute on function public.prepare_guest_welcome_claim(uuid,uuid) to service_role;
grant execute on function public.assert_guest_welcome_lease(uuid,uuid) to service_role;
grant execute on function public.mark_guest_welcome_eligible(uuid,uuid) to service_role;
grant execute on function public.complete_guest_welcome_claim(uuid,uuid) to service_role;
grant execute on function public.deny_guest_welcome_claim(uuid,uuid) to service_role;
grant execute on function public.release_guest_welcome_lease(uuid) to service_role;
commit;
