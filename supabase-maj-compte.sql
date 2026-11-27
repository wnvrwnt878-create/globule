-- Globule, mise à jour du 27/11/2026 : suppression du compte par l'utilisateur.
-- À coller une seule fois dans Supabase > SQL Editor > New query, puis Run.
-- Le bouton « Supprimer mon compte » appelle cette fonction : elle efface tout ce qui appartient
-- à la personne connectée (tests, séances, liens entraîneur, profil), puis son compte.

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Non connecté'; end if;
  delete from public.tests where user_id = me;
  delete from public.sessions where user_id = me;
  delete from public.coach_links where athlete_id = me or coach_id = me;
  delete from public.profiles where id = me;
  delete from auth.users where id = me;
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

notify pgrst, 'reload schema';
