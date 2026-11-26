create table public.portal_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text check (role in ('employee', 'deputy', 'commissioner'))
);

alter table public.portal_accounts enable row level security;
revoke all on public.portal_accounts from anon, authenticated;
grant select on public.portal_accounts to authenticated;

create function public.portal_is_leader()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.portal_accounts
    where user_id = (select auth.uid()) and role in ('commissioner', 'deputy')
  );
$$;

revoke all on function public.portal_is_leader() from public, anon;
grant execute on function public.portal_is_leader() to authenticated;

create policy read_portal_accounts on public.portal_accounts
for select to authenticated
using (user_id = (select auth.uid()) or ((select public.portal_is_leader()) and role is null));

create function public.portal_register_account()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.portal_accounts (user_id, email) values (new.id, new.email);
  return new;
end;
$$;

revoke all on function public.portal_register_account() from public, anon, authenticated;

create trigger portal_account_after_signup
after insert on auth.users
for each row execute function public.portal_register_account();

insert into public.portal_accounts (user_id, email)
select id, email from auth.users
on conflict (user_id) do nothing;

create function public.portal_assign_role(target_user uuid, target_role text)
returns void language plpgsql security definer set search_path = ''
as $$
declare actor_role text;
begin
  select role into actor_role from public.portal_accounts
  where user_id = (select auth.uid()) for share;

  if target_role is null or not coalesce(
    (actor_role = 'commissioner' and target_role in ('employee', 'deputy')) or
    (actor_role = 'deputy' and target_role = 'employee'), false
  ) then
    raise exception 'Role assignment is not permitted' using errcode = '42501';
  end if;

  update public.portal_accounts set role = target_role
  where user_id = target_user and role is null
    and exists (select 1 from auth.users where id = target_user and confirmed_at is not null);
  if not found then
    raise exception 'Confirmed account without a role not found';
  end if;
end;
$$;

revoke all on function public.portal_assign_role(uuid, text) from public, anon;
grant execute on function public.portal_assign_role(uuid, text) to authenticated;
