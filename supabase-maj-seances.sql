-- Globule, mise à jour du 14/11/2026 : séances préenregistrées.
-- À coller une fois dans Supabase > SQL Editor > New query, puis Run.
alter table public.sessions add column if not exists intervals jsonb;
alter table public.sessions add column if not exists template jsonb;
notify pgrst, 'reload schema';
