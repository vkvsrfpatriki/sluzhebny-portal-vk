create function public.portal_weekly_submission_roster(start_date date, end_date date)
returns table(employee_id uuid, employee_name text, employee_static text, report_id uuid,
 report_created_at timestamptz, report_status text, report_points bigint, approved_id uuid,
 approved_created_at timestamptz, approved_points bigint)
language sql stable security definer set search_path=''
as $$
 select a.user_id, coalesce(nullif(trim(a.game_name),''), nullif(trim(u.raw_user_meta_data->>'name'),''), 'Имя не указано'),
 a.game_static, latest.id, latest.created_at, latest.review_status, latest.weekly_points,
 approved.id, approved.created_at, approved.weekly_points
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 left join lateral (
  select r.id,r.created_at,r.review_status,r.weekly_points from public.portal_reports r
  where r.author_id=a.user_id and r.kind='weekly' and r.deleted_at is null
   and r.week_start=start_date and r.week_end=end_date
  order by r.created_at desc,r.id desc limit 1
 ) latest on true
 left join lateral (
  select r.id,r.created_at,r.weekly_points from public.portal_reports r
  where r.author_id=a.user_id and r.kind='weekly' and r.deleted_at is null and r.review_status='approved'
   and r.week_start=start_date and r.week_end=end_date
  order by r.created_at desc,r.id desc limit 1
 ) approved on true
 where a.role is not null and (select public.portal_is_leader())
 order by a.game_name,a.user_id;
$$;
revoke all on function public.portal_weekly_submission_roster(date,date) from public,anon;
grant execute on function public.portal_weekly_submission_roster(date,date) to authenticated;