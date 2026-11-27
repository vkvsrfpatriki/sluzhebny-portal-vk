alter policy manage_bonus_statements on public.portal_bonus_statements
using ((select public.portal_is_leader()))
with check ((select public.portal_is_leader()));

CREATE OR REPLACE FUNCTION public.portal_bonus_roster(start_date date, end_date date)
 RETURNS TABLE(employee_name text, submitted boolean, points bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select coalesce(nullif(a.game_name,''),nullif(u.raw_user_meta_data->>'name',''),'Имя не указано'),
 r.id is not null,r.weekly_points
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 left join lateral (
 select id,weekly_points from public.portal_reports
 where author_id=a.user_id and kind='weekly' and deleted_at is null
 and week_start=start_date and week_end=end_date
 order by created_at desc,id desc limit 1
 ) r on true
 where a.role in ('employee','deputy','trainee')
 and (select public.portal_is_leader())
 order by a.game_name,a.user_id;
$function$;

CREATE OR REPLACE FUNCTION public.portal_bonus_statement_details(start_date date, end_date date)
 RETURNS TABLE(employee_name text, submitted boolean, points bigint, report_id uuid, review_status text, latest_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select coalesce(nullif(a.game_name,''),nullif(u.raw_user_meta_data->>'name',''),'Имя не указано'),
 r.id is not null,r.weekly_points,r.id,r.review_status,latest.review_status
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 left join lateral (
 select id,weekly_points,review_status from public.portal_reports
 where author_id=a.user_id and kind='weekly' and deleted_at is null
 and week_start=start_date and week_end=end_date and review_status='approved'
 order by created_at desc,id desc limit 1
 ) r on true
 left join lateral (
 select x.review_status from public.portal_reports x
 where x.author_id=a.user_id and x.kind='weekly' and x.deleted_at is null
 and x.week_start=start_date and x.week_end=end_date
 order by x.created_at desc,x.id desc limit 1
 ) latest on true
 where a.role in ('employee','deputy','trainee')
 and (select public.portal_is_leader())
 order by a.game_name,a.user_id;
$function$;

CREATE OR REPLACE FUNCTION public.portal_bonus_statement_roster(start_date date, end_date date)
 RETURNS TABLE(employee_name text, submitted boolean, points bigint, report_id uuid, review_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select coalesce(nullif(a.game_name,''),nullif(u.raw_user_meta_data->>'name',''),'Имя не указано'),
 r.id is not null,r.weekly_points,r.id,r.review_status
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 left join lateral (
 select id,weekly_points,review_status from public.portal_reports
 where author_id=a.user_id and kind='weekly' and deleted_at is null
 and week_start=start_date and week_end=end_date and review_status='approved'
 order by created_at desc,id desc limit 1
 ) r on true
 where a.role in ('employee','deputy','trainee')
 and (select public.portal_is_leader())
 order by a.game_name,a.user_id;
$function$;
