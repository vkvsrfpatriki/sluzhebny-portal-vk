revoke insert (week_start,week_end,weekly_points) on public.portal_reports from authenticated;
alter policy submit_portal_reports on public.portal_reports with check (
 kind='promotion' and author_id=(select auth.uid()) and exists (
 select 1 from public.portal_accounts where user_id=(select auth.uid()) and role is not null
 )
);