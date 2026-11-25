-- Globule, mise à jour du 25/11/2026 : profil course.
-- En course, l'intensité est une vitesse en km/h avec décimales (ex. 12,5).
-- La colonne "watts" des séances passe donc en nombre décimal. Les données existantes ne changent pas.
-- À coller une seule fois dans Supabase > SQL Editor > New query, puis Run.
alter table public.sessions alter column watts type numeric using watts::numeric;
notify pgrst, 'reload schema';
