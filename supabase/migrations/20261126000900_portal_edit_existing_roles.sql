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
 update public.portal_accounts set role=target_role where user_id=target_user and user_id is distinct from auth.uid()
 and role is distinct from 'commissioner'
 and (actor_role='commissioner' or role is distinct from 'deputy')
 and exists (select 1 from auth.users where id=target_user and confirmed_at is not null);
 if not found then raise exception 'Account not found or role cannot be edited'; end if;
end;
$$;
