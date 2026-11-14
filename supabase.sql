-- Globule : tables et règles d'accès.
-- À coller une seule fois dans Supabase > SQL Editor > New query, puis Run.
-- Chaque personne ne voit et ne modifie que ses propres tests et séances.

create table if not exists public.tests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  date date not null,
  kind text not null default 'steps',
  source text,
  data jsonb,
  note text,
  lt1_manual numeric,
  lt2_manual numeric
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  date date not null,
  kind text,
  duration_min integer,
  watts integer,
  hr integer,
  lactate numeric,
  rpe integer,
  source text,
  note text,
  intervals jsonb,
  template jsonb
);

-- Mise à jour du 14/11/2026 : séances préenregistrées, valeurs intervalle par intervalle.
alter table public.sessions add column if not exists intervals jsonb;
alter table public.sessions add column if not exists template jsonb;
notify pgrst, 'reload schema';

create index if not exists tests_user_date on public.tests (user_id, date desc);
create index if not exists sessions_user_date on public.sessions (user_id, date desc);

alter table public.tests enable row level security;
alter table public.sessions enable row level security;

drop policy if exists "tests: les miens" on public.tests;
create policy "tests: les miens" on public.tests
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "sessions: les miennes" on public.sessions;
create policy "sessions: les miennes" on public.sessions
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
