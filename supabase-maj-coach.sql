-- Globule, mise à jour du 27/11/2026 : mode entraîneur (lecture seule).
-- À coller une seule fois dans Supabase > SQL Editor > New query, puis Run.
--
-- Principe : l'athlète crée un code d'invitation, l'entraîneur le saisit.
-- Tant que le lien est actif, l'entraîneur peut LIRE les tests, les séances et le profil de l'athlète.
-- Il ne peut rien modifier. L'athlète peut retirer l'accès à tout moment (le lien est supprimé).

-- 1. Profil partageable (prénom, sports, Golden Zone, protocoles, modèles). Copie des réglages de l'athlète.
create table if not exists public.profiles (
  id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  name text,
  sports jsonb,
  gz jsonb,
  gz_on boolean,
  protos jsonb,
  templates jsonb,
  updated_at timestamptz not null default now()
);

-- 2. Liens entraîneur ↔ athlète
create table if not exists public.coach_links (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  coach_id uuid references auth.users (id) on delete cascade,
  code text unique,
  status text not null default 'pending' check (status in ('pending', 'active')),
  athlete_name text,
  coach_name text,
  created_at timestamptz not null default now()
);
create index if not exists coach_links_coach on public.coach_links (coach_id);
create index if not exists coach_links_athlete on public.coach_links (athlete_id);

alter table public.profiles enable row level security;
alter table public.coach_links enable row level security;

-- Est-ce que l'utilisateur connecté entraîne cet athlète (lien actif) ?
create or replace function public.is_coach_of(p_athlete uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.coach_links l
                 where l.athlete_id = p_athlete and l.coach_id = auth.uid() and l.status = 'active');
$$;

-- Profils : chacun gère le sien, l'entraîneur lit celui de ses athlètes
drop policy if exists "profiles: le mien" on public.profiles;
create policy "profiles: le mien" on public.profiles
  for all to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
drop policy if exists "profiles: mes athlètes (lecture)" on public.profiles;
create policy "profiles: mes athlètes (lecture)" on public.profiles
  for select to authenticated
  using (public.is_coach_of(id));

-- Liens : l'athlète crée et supprime ; l'athlète et l'entraîneur les lisent ; l'entraîneur peut se retirer
drop policy if exists "liens: lecture" on public.coach_links;
create policy "liens: lecture" on public.coach_links
  for select to authenticated
  using (athlete_id = (select auth.uid()) or coach_id = (select auth.uid()));
drop policy if exists "liens: l'athlète crée" on public.coach_links;
create policy "liens: l'athlète crée" on public.coach_links
  for insert to authenticated
  with check (athlete_id = (select auth.uid()) and coach_id is null and status = 'pending');
drop policy if exists "liens: suppression" on public.coach_links;
create policy "liens: suppression" on public.coach_links
  for delete to authenticated
  using (athlete_id = (select auth.uid()) or coach_id = (select auth.uid()));

-- L'entraîneur accepte un code : seule porte d'entrée pour devenir entraîneur d'un athlète
create or replace function public.claim_coach_code(p_code text, p_coach_name text)
returns text language plpgsql security definer set search_path = public as $$
declare l public.coach_links;
begin
  select * into l from public.coach_links
   where code = upper(trim(p_code)) and status = 'pending' and created_at > now() - interval '7 days'
   for update;
  if not found then raise exception 'Code inconnu, déjà utilisé ou expiré'; end if;
  if l.athlete_id = auth.uid() then raise exception 'Ce code est le tien : donne-le à ton entraîneur'; end if;
  update public.coach_links set coach_id = auth.uid(), status = 'active', coach_name = p_coach_name, code = null
   where id = l.id;
  return coalesce(l.athlete_name, '');
end;
$$;
revoke all on function public.claim_coach_code(text, text) from public;
grant execute on function public.claim_coach_code(text, text) to authenticated;

-- 3. Tests et séances : l'entraîneur lit ceux de ses athlètes (en plus des règles existantes)
drop policy if exists "tests: mes athlètes (lecture)" on public.tests;
create policy "tests: mes athlètes (lecture)" on public.tests
  for select to authenticated
  using (public.is_coach_of(user_id));
drop policy if exists "sessions: mes athlètes (lecture)" on public.sessions;
create policy "sessions: mes athlètes (lecture)" on public.sessions
  for select to authenticated
  using (public.is_coach_of(user_id));

notify pgrst, 'reload schema';
