alter table public.portal_reports
 add column week_start date,
 add column week_end date,
 add column weekly_points bigint check (weekly_points >= 0),
 add constraint portal_report_week_fields check (
  (week_start is null and week_end is null and weekly_points is null)
  or (kind = 'weekly' and week_start is not null and week_end is not null and weekly_points is not null and week_end >= week_start)
 );
grant insert (week_start, week_end, weekly_points) on public.portal_reports to authenticated;
create index portal_reports_week_summary_idx on public.portal_reports(author_id, week_start, week_end, created_at desc) where kind='weekly' and deleted_at is null;