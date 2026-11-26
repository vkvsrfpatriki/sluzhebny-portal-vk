alter table public.portal_accounts
 add column game_name text not null default '',
 add column game_rank text not null default '',
 add column game_static text not null default '',
 add column game_position text not null default '';

create table public.portal_profile_log (
 id bigint generated always as identity primary key,
 target_id uuid not null,
 editor_id uuid not null,
 previous_values jsonb not null,
 new_values jsonb not null,
 changed_at timestamptz not null default now()
);
alter table public.portal_profile_log enable row level security;
revoke all on public.portal_profile_log from anon, authenticated;
grant select on public.portal_profile_log to authenticated;
create policy read_portal_profile_log on public.portal_profile_log for select to authenticated
 using ((select public.portal_is_leader()));

create function public.portal_save_profile(target_user uuid, player_name text, player_rank text, player_static text, player_position text)
returns void language plpgsql security definer set search_path = ''
as $$
declare
 actor uuid := auth.uid();
 prior jsonb;
 updated jsonb;
begin
 if actor is null or not exists (
  select 1 from public.portal_accounts where user_id = actor and role is not null
 ) or (target_user is distinct from actor and not public.portal_is_leader()) then
  raise exception 'Profile editing is not permitted' using errcode = '42501';
 end if;
 player_name := trim(coalesce(player_name, ''));
 player_rank := trim(coalesce(player_rank, ''));
 player_static := trim(coalesce(player_static, ''));
 player_position := trim(coalesce(player_position, ''));
 if char_length(player_name) not between 1 and 100 or
    char_length(player_rank) not between 1 and 80 or
    char_length(player_static) not between 1 and 40 or char_length(player_position) > 100 then
  raise exception 'Invalid profile fields' using errcode = '22023';
 end if;
 select jsonb_build_object('name',game_name,'rank',game_rank,'static',game_static,'position',game_position)
 into prior from public.portal_accounts where user_id=target_user and role is not null for update;
 if not found then raise exception 'Profile not found'; end if;
 updated := jsonb_build_object('name',player_name,'rank',player_rank,'static',player_static,'position',player_position);
 if prior = updated then return; end if;
 update public.portal_accounts set game_name=player_name, game_rank=player_rank,
  game_static=player_static, game_position=player_position where user_id=target_user;
 insert into public.portal_profile_log(target_id,editor_id,previous_values,new_values) values (target_user,actor,prior,updated);
end;
$$;
revoke all on function public.portal_save_profile(uuid,text,text,text,text) from public, anon;
grant execute on function public.portal_save_profile(uuid,text,text,text,text) to authenticated;

create function public.portal_manage_profiles()
returns table(user_id uuid, discord_name text, game_name text, game_rank text, game_static text, game_position text)
language sql stable security definer set search_path = ''
as $$
 select a.user_id, left(coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'),''),
 nullif(trim(u.raw_user_meta_data->>'name'),''), nullif(trim(u.raw_user_meta_data->>'preferred_username'),''), 'Discord'),80),
 a.game_name,a.game_rank,a.game_static,a.game_position
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 where a.role is not null and public.portal_is_leader()
 order by a.game_name,a.user_id;
$$;
revoke all on function public.portal_manage_profiles() from public, anon;
grant execute on function public.portal_manage_profiles() to authenticated;