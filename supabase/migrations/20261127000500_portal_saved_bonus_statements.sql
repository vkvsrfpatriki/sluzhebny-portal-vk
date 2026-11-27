create table public.portal_bonus_statements (
 week_start date primary key check(extract(isodow from week_start)=1),
 statement text not null check(length(statement) between 1 and 100000),
 saved_at timestamptz not null default now()
);
alter table public.portal_bonus_statements enable row level security;
revoke all on public.portal_bonus_statements from anon, authenticated;
grant select,insert,update on public.portal_bonus_statements to authenticated;
create policy manage_bonus_statements on public.portal_bonus_statements for all to authenticated
using (exists(select 1 from public.portal_accounts where user_id=(select auth.uid()) and role='commissioner'))
with check (exists(select 1 from public.portal_accounts where user_id=(select auth.uid()) and role='commissioner'));