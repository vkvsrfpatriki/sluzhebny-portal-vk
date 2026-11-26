alter table public.portal_accounts drop constraint portal_accounts_role_check;
alter table public.portal_accounts add constraint portal_accounts_role_check check (role in ('trainee','employee','deputy','commissioner'));
create or replace function public.portal_assign_role(target_user uuid, target_role text)
returns void language plpgsql security definer set search_path = ''
as $$
declare actor_role text;
begin
 select role into actor_role from public.portal_accounts where user_id=(select auth.uid()) for share;
 if not coalesce((actor_role='commissioner' and target_role in ('trainee','employee','deputy')) or
 (actor_role='deputy' and target_role in ('trainee','employee')),false) then
  raise exception 'Role assignment is not permitted' using errcode='42501';
 end if;
 update public.portal_accounts set role=target_role where user_id=target_user and role is null
 and exists (select 1 from auth.users where id=target_user and confirmed_at is not null);
 if not found then raise exception 'Confirmed account without a role not found'; end if;
end;
$$;
create function public.portal_role_directory()
returns table(user_id uuid, staff_role text, game_name text, game_static text, discord_name text, discord_id text, last_sign_in timestamptz)
language sql stable security definer set search_path=''
as $$
 select a.user_id,a.role,a.game_name,a.game_static,
 left(coalesce(i.identity_data->>'full_name',i.identity_data->>'name',i.identity_data->>'preferred_username','Пользователь'),100),
 i.provider_id,u.last_sign_in_at
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 left join lateral (select x.identity_data,x.provider_id from auth.identities x where x.user_id=u.id and x.provider='discord' order by x.created_at limit 1) i on true
 where u.confirmed_at is not null and (select public.portal_is_leader())
 order by a.role is not null, u.last_sign_in_at desc nulls last, a.user_id;
$$;
revoke all on function public.portal_role_directory() from public, anon;
grant execute on function public.portal_role_directory() to authenticated;