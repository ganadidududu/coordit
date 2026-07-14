create table if not exists public.consent_versions (
  key text not null,
  version text not null,
  title text not null,
  description text,
  required boolean not null default false,
  effective_from timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (key, version),
  constraint consent_versions_key_not_blank check (btrim(key) <> ''),
  constraint consent_versions_version_not_blank check (btrim(version) <> '')
);

create table if not exists public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  consent_key text not null,
  consent_version text not null,
  accepted boolean not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  required boolean not null default false,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (consent_key, consent_version) references public.consent_versions(key, version) on update cascade on delete restrict,
  unique (user_id, consent_key, consent_version),
  constraint user_consents_key_not_blank check (btrim(consent_key) <> ''),
  constraint user_consents_version_not_blank check (btrim(consent_version) <> ''),
  constraint user_consents_accepted_at_required check (accepted = false or accepted_at is not null),
  constraint user_consents_revoked_after_accepted check (revoked_at is null or accepted_at is null or revoked_at >= accepted_at)
);

insert into public.consent_versions (key, version, title, description, required, effective_from)
values
  ('terms_of_service', '2026-07-07', 'Terms of Service', 'Required agreement to Coordit service terms.', true, '2026-07-07 00:00:00+00'),
  ('privacy_policy', '2026-07-07', 'Privacy Policy', 'Required agreement to Coordit privacy policy.', true, '2026-07-07 00:00:00+00'),
  ('fit_data_improvement', '2026-07-07', 'Fit Data Improvement', 'Optional consent to use fit feedback and measurement data to improve recommendations.', false, '2026-07-07 00:00:00+00'),
  ('marketing', '2026-07-07', 'Marketing Communications', 'Optional consent to receive product updates and marketing communications.', false, '2026-07-07 00:00:00+00')
on conflict (key, version) do update set
  title = excluded.title,
  description = excluded.description,
  required = excluded.required,
  effective_from = excluded.effective_from;

create index if not exists idx_consent_versions_required_effective on public.consent_versions(required, effective_from desc);
create index if not exists idx_user_consents_user_key on public.user_consents(user_id, consent_key);
create index if not exists idx_user_consents_user_created_at on public.user_consents(user_id, created_at desc);

alter table public.consent_versions enable row level security;
alter table public.user_consents enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'consent_versions'
      and policyname = 'authenticated users can read consent versions'
  ) then
    create policy "authenticated users can read consent versions"
      on public.consent_versions
      for select
      using (auth.role() = 'authenticated');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_consents'
      and policyname = 'users can read own consents'
  ) then
    create policy "users can read own consents"
      on public.user_consents
      for select
      using (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_consents'
      and policyname = 'users can insert own consents'
  ) then
    create policy "users can insert own consents"
      on public.user_consents
      for insert
      with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_consents'
      and policyname = 'users can update own consents'
  ) then
    create policy "users can update own consents"
      on public.user_consents
      for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;
