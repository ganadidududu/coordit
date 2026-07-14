create extension if not exists "pgcrypto";

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  display_name text,
  gender text,
  birth_year integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.consent_versions (
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

create table public.user_consents (
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

create table public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  height_cm numeric(5,2),
  weight_kg numeric(5,2),
  shoulder_width numeric(5,2),
  chest_circumference numeric(5,2),
  waist_circumference numeric(5,2),
  hip_circumference numeric(5,2),
  outseam numeric(5,2),
  raw_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.clothing_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  brand text,
  category text not null,
  fit_type text not null default 'regular',
  size_label text,
  notes text,
  image_url text,
  raw_product_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.clothing_sizes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  clothing_item_id uuid not null references public.clothing_items(id) on delete cascade,
  size_label text,
  total_length numeric(5,2),
  shoulder_width numeric(5,2),
  chest_width numeric(5,2),
  sleeve_length numeric(5,2),
  waist_width numeric(5,2),
  hip_width numeric(5,2),
  rise numeric(5,2),
  outseam numeric(5,2),
  raw_measurements jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reference_clothing (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  clothing_item_id uuid not null references public.clothing_items(id) on delete cascade,
  nickname text,
  category text not null,
  fit_type text not null default 'regular',
  preference_score integer not null default 100 check (preference_score between 1 and 100),
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, clothing_item_id)
);

create table public.external_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  product_name text not null,
  brand text,
  mall_name text,
  product_url text,
  category text not null,
  fit_type text not null default 'regular',
  image_url text,
  raw_product_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.external_product_sizes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  external_product_id uuid not null references public.external_products(id) on delete cascade,
  size_label text not null,
  total_length numeric(5,2),
  shoulder_width numeric(5,2),
  chest_width numeric(5,2),
  sleeve_length numeric(5,2),
  waist_width numeric(5,2),
  hip_width numeric(5,2),
  rise numeric(5,2),
  outseam numeric(5,2),
  raw_size_data jsonb not null default '{}'::jsonb,
  parsing_status text not null default 'manual',
  measurement_source text not null default 'manual',
  extracted_text text,
  extraction_confidence numeric(5,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.fit_analysis_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  reference_clothing_id uuid not null references public.reference_clothing(id) on delete restrict,
  external_product_id uuid not null references public.external_products(id) on delete cascade,
  recommended_external_product_size_id uuid references public.external_product_sizes(id) on delete set null,
  recommended_size_label text not null,
  fit_score numeric(6,2) not null,
  fit_label text not null,
  fit_comment text not null,
  weighted_fit_distance numeric(6,3) not null,
  algorithm_version text not null,
  recommendation_confidence text not null default 'low',
  result_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.user_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  fit_analysis_result_id uuid not null references public.fit_analysis_results(id) on delete cascade,
  purchased_size_label text,
  actual_fit_rating integer check (actual_fit_rating between 1 and 5),
  actual_fit_label text,
  part_feedback jsonb not null default '{}'::jsonb,
  comment text,
  raw_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.recommendation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  fit_analysis_result_id uuid references public.fit_analysis_results(id) on delete cascade,
  external_product_id uuid references public.external_products(id) on delete cascade,
  recommended_size_label text,
  event_type text not null default 'shown',
  clicked_at timestamptz,
  purchased_at timestamptz,
  algorithm_version text not null,
  raw_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
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
