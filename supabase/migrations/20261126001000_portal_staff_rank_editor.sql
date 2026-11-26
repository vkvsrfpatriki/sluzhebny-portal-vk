drop function public.portal_role_directory();
create function public.portal_role_directory()
returns table(user_id uuid, staff_role text, game_name text, game_static text, game_rank text, discord_name text, discord_id text, last_sign_in timestamptz)
language sql stable security definer set search_path=''
as $$
 select a.user_id,a.role,a.game_name,a.game_static,a.game_rank,
 left(coalesce(i.identity_data->>'full_name',i.identity_data->>'name',i.identity_data->>'preferred_username','Пользователь'),100),
 i.provider_id,u.last_sign_in_at
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 left join lateral (select x.identity_data,x.provider_id from auth.identities x where x.user_id=u.id and x.provider='discord' order by x.created_at limit 1) i on true
 where u.confirmed_at is not null and (select public.portal_is_leader())
 order by a.role is not null, u.last_sign_in_at desc nulls last, a.user_id;
$$;
revoke all on function public.portal_role_directory() from public, anon;
grant execute on function public.portal_role_directory() to authenticated;

create function public.portal_change_staff_rank(target_user uuid, target_rank text)
returns void language plpgsql security definer set search_path=''
as $$
declare
 actor uuid := auth.uid();
 actor_role text;
 prior jsonb;
begin
 select role into actor_role from public.portal_accounts where user_id=actor and role in ('commissioner','deputy') for update;
 if not found then raise exception 'Rank editing is not permitted' using errcode='42501'; end if;
 if target_rank is null or target_rank not in ('Рядовой','Ефрейтор','Младший сержант','Сержант','Старший сержант','Старшина','Прапорщик','Старший прапорщик','Младший лейтенант','Лейтенант','Старший лейтенант','Капитан','Майор','Подполковник') then
  raise exception 'Invalid rank' using errcode='22023';
 end if;
 select jsonb_build_object('name',game_name,'rank',game_rank,'static',game_static,'position',game_position)
 into prior from public.portal_accounts
 where user_id=target_user and role is not null and (
  target_user=actor or role in ('trainee','employee') or (actor_role='commissioner' and role='deputy')
 ) for update;
 if not found then raise exception 'Rank editing is not permitted' using errcode='42501'; end if;
 if prior->>'rank'=target_rank then return; end if;
 update public.portal_accounts set game_rank=target_rank where user_id=target_user;
 insert into public.portal_profile_log(target_id,editor_id,previous_values,new_values)
 values(target_user,actor,prior,jsonb_set(prior,'{rank}',to_jsonb(target_rank)));
end;
$$;
revoke all on function public.portal_change_staff_rank(uuid,text) from public, anon;
grant execute on function public.portal_change_staff_rank(uuid,text) to authenticated;