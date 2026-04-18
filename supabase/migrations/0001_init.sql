-- Sankalpa — Phase 1 schema
--
-- Creates the multi-tenant data model + Row-Level Security policies for the
-- manifestation app. Mirrors `Knowledge/manifestation-app-brief.md` §9 and the
-- specifics in `Tasks/manifestation-app-phase1-data-model.md`.
--
-- Safe to run twice — every CREATE is gated with IF NOT EXISTS where Postgres
-- supports it, and the trigger / policy creates are wrapped to be idempotent.

----------------------------------------------------------------------
-- 0. Extensions
----------------------------------------------------------------------
create extension if not exists "pgcrypto"; -- gen_random_uuid()

----------------------------------------------------------------------
-- 1. user_profiles
----------------------------------------------------------------------
create table if not exists public.user_profiles (
  user_id      uuid primary key references auth.users on delete cascade,
  display_name text,
  settings     jsonb not null default jsonb_build_object(
    'sound_enabled',         true,
    'default_soundscape_id', null,
    'app_theme',             'cream',
    'reminder_times',        '[]'::jsonb,
    'week_starts_on',        'monday',
    'imported_seed',         false
  ),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

----------------------------------------------------------------------
-- 2. categories
----------------------------------------------------------------------
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users on delete cascade,
  name        text not null,
  icon        text not null default 'sparkles', -- lucide icon name
  color       text not null default '#C8A24B',  -- accent palette hex
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists categories_user_idx
  on public.categories (user_id, sort_order);

----------------------------------------------------------------------
-- 3. soundscapes
----------------------------------------------------------------------
create table if not exists public.soundscapes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users on delete cascade, -- null for system rows
  name       text not null,
  url        text not null,
  kind       text not null check (kind in ('solfeggio', 'nature', 'music')),
  is_system  bool not null default false,
  created_at timestamptz not null default now()
);

create index if not exists soundscapes_user_idx
  on public.soundscapes (user_id) where user_id is not null;

create index if not exists soundscapes_system_idx
  on public.soundscapes (is_system) where is_system = true;

----------------------------------------------------------------------
-- 4. manifestations
----------------------------------------------------------------------
create table if not exists public.manifestations (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users on delete cascade,
  category_id    uuid references public.categories on delete set null,
  text           text not null,
  sort_order     int  not null default 0,
  status         text not null default 'active'
    check (status in ('active', 'manifested', 'archived')),
  -- Backdrop
  backdrop_type  text not null default 'theme'
    check (backdrop_type in ('theme', 'image')),
  theme_id       text not null default 'chocolate'
    check (theme_id in ('chocolate', 'cream', 'sage', 'dusk', 'ocean', 'terracotta')),
  image_url      text,
  image_prompt   text,
  image_style    text check (image_style in ('cinematic', 'dreamy_watercolor', 'minimalist', 'japanese_ink')),
  text_variant   text not null default 'regular' check (text_variant in ('regular', 'italic')),
  voice_url      text, -- Phase 2
  sound_id       uuid references public.soundscapes on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  manifested_at  timestamptz
);

create index if not exists manifestations_user_idx
  on public.manifestations (user_id, sort_order)
  where status = 'active';

create index if not exists manifestations_category_idx
  on public.manifestations (category_id);

----------------------------------------------------------------------
-- 5. sessions
----------------------------------------------------------------------
create table if not exists public.sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users on delete cascade,
  mode        text not null default 'morning'
    check (mode in ('morning', 'evening', 'quick', 'deep')),
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  cards_read  int not null default 0,
  duration_s  int not null default 0
);

create index if not exists sessions_user_started_idx
  on public.sessions (user_id, started_at desc);

----------------------------------------------------------------------
-- 6. evidence (Phase 2 — created now for forward compatibility)
----------------------------------------------------------------------
create table if not exists public.evidence (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users on delete cascade,
  manifestation_id uuid not null references public.manifestations on delete cascade,
  note             text,
  media_url        text,
  logged_at        timestamptz not null default now()
);

create index if not exists evidence_user_idx
  on public.evidence (user_id, logged_at desc);

create index if not exists evidence_manifestation_idx
  on public.evidence (manifestation_id);

----------------------------------------------------------------------
-- 7. updated_at trigger helper
----------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists user_profiles_set_updated_at on public.user_profiles;
create trigger user_profiles_set_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

drop trigger if exists manifestations_set_updated_at on public.manifestations;
create trigger manifestations_set_updated_at
  before update on public.manifestations
  for each row execute function public.set_updated_at();

----------------------------------------------------------------------
-- 8. Row-Level Security
----------------------------------------------------------------------
alter table public.user_profiles  enable row level security;
alter table public.categories     enable row level security;
alter table public.manifestations enable row level security;
alter table public.sessions       enable row level security;
alter table public.evidence       enable row level security;
alter table public.soundscapes    enable row level security;

-- user_profiles: each user can read/write only their own row
drop policy if exists "user_profiles owner can read"   on public.user_profiles;
drop policy if exists "user_profiles owner can write"  on public.user_profiles;

create policy "user_profiles owner can read"
  on public.user_profiles for select
  using (auth.uid() = user_id);

create policy "user_profiles owner can write"
  on public.user_profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- categories: owner-only across the board
drop policy if exists "categories owner can read"  on public.categories;
drop policy if exists "categories owner can write" on public.categories;

create policy "categories owner can read"
  on public.categories for select
  using (auth.uid() = user_id);

create policy "categories owner can write"
  on public.categories for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- manifestations: owner-only
drop policy if exists "manifestations owner can read"  on public.manifestations;
drop policy if exists "manifestations owner can write" on public.manifestations;

create policy "manifestations owner can read"
  on public.manifestations for select
  using (auth.uid() = user_id);

create policy "manifestations owner can write"
  on public.manifestations for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- sessions: owner-only
drop policy if exists "sessions owner can read"  on public.sessions;
drop policy if exists "sessions owner can write" on public.sessions;

create policy "sessions owner can read"
  on public.sessions for select
  using (auth.uid() = user_id);

create policy "sessions owner can write"
  on public.sessions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- evidence: owner-only
drop policy if exists "evidence owner can read"  on public.evidence;
drop policy if exists "evidence owner can write" on public.evidence;

create policy "evidence owner can read"
  on public.evidence for select
  using (auth.uid() = user_id);

create policy "evidence owner can write"
  on public.evidence for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- soundscapes: system rows readable by everyone; users own their uploads
drop policy if exists "soundscapes readable by all"     on public.soundscapes;
drop policy if exists "soundscapes owner can write"     on public.soundscapes;

create policy "soundscapes readable by all"
  on public.soundscapes for select
  using (
    is_system = true
    or auth.uid() = user_id
  );

create policy "soundscapes owner can write"
  on public.soundscapes for all
  using (
    auth.uid() = user_id
    and is_system = false
  )
  with check (
    auth.uid() = user_id
    and is_system = false
  );

----------------------------------------------------------------------
-- 9. Auto-provision profile + default categories on first sign-in
----------------------------------------------------------------------
-- Default category set (sort_order matches the recommended ritual flow:
-- Self → Health → Family → Career → Wealth → Legal/Residency → Divine)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', null))
  on conflict (user_id) do nothing;

  insert into public.categories (user_id, name, icon, color, sort_order) values
    (new.id, 'Self',             'mountain',         '#9A8FBF', 0),
    (new.id, 'Health',           'leaf',             '#7A8B6F', 1),
    (new.id, 'Family',           'heart-handshake',  '#B87361', 2),
    (new.id, 'Career',           'briefcase',        '#9A8FBF', 3),
    (new.id, 'Wealth',           'sprout',           '#C8A24B', 4),
    (new.id, 'Legal & Residency','key-round',        '#6F8BA1', 5),
    (new.id, 'Divine',           'sparkles',         '#C8A24B', 6);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

----------------------------------------------------------------------
-- 10. System soundscapes (Solfeggio + nature placeholders)
--
-- URLs are PLACEHOLDERS — replace with the final royalty-free CDN URLs
-- (Pixabay, Mixkit, freesound CC0, or your own Cloudflare R2 bucket) before
-- shipping the ritual-mode task. The rows still resolve cleanly today; they
-- just won't play audio until the URLs are real.
----------------------------------------------------------------------
insert into public.soundscapes (id, user_id, name, url, kind, is_system) values
  ('11111111-1111-1111-1111-000000000001', null, '528 Hz — Love frequency',  'https://placeholder.local/sankalpa/528hz.mp3',     'solfeggio', true),
  ('11111111-1111-1111-1111-000000000002', null, '432 Hz — Calm tone',       'https://placeholder.local/sankalpa/432hz.mp3',     'solfeggio', true),
  ('11111111-1111-1111-1111-000000000003', null, 'Rain — gentle',            'https://placeholder.local/sankalpa/rain.mp3',      'nature',    true),
  ('11111111-1111-1111-1111-000000000004', null, 'Ocean — soft waves',       'https://placeholder.local/sankalpa/ocean.mp3',     'nature',    true),
  ('11111111-1111-1111-1111-000000000005', null, 'Piano — slow ambient',     'https://placeholder.local/sankalpa/piano.mp3',     'music',     true)
on conflict (id) do nothing;
