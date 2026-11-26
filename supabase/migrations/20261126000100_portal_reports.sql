create table public.portal_reports (
 id uuid primary key,
 author_id uuid not null default auth.uid() references public.portal_accounts(user_id),
 kind text not null check (kind in ('weekly', 'promotion')),
 body text not null check (char_length(trim(body)) between 1 and 100000),
 created_at timestamptz not null default now()
);
alter table public.portal_reports enable row level security;
revoke all on public.portal_reports from anon, authenticated;
grant select on public.portal_reports to authenticated;
grant insert (id, kind, body) on public.portal_reports to authenticated;
create policy submit_portal_reports on public.portal_reports for insert to authenticated
with check (author_id = (select auth.uid()) and exists (
 select 1 from public.portal_accounts where user_id = (select auth.uid()) and role is not null
));
create policy read_portal_reports on public.portal_reports for select to authenticated
using (author_id = (select auth.uid()) or (select public.portal_is_leader()));
create index portal_reports_created_at_idx on public.portal_reports (created_at desc, id);
create index portal_reports_author_id_idx on public.portal_reports (author_id);