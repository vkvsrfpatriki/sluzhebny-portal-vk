create function public.portal_bonus_statement_roster(start_date date,end_date date)
returns table(employee_name text, submitted boolean, points bigint, report_id uuid, review_status text)
language sql stable security definer set search_path=''
as $$
 select coalesce(nullif(a.game_name,''),nullif(u.raw_user_meta_data->>'name',''),'Имя не указано'),
 r.id is not null,r.weekly_points,r.id,r.review_status
 from public.portal_accounts a join auth.users u on u.id=a.user_id
 left join lateral (
 select id,weekly_points,review_status from public.portal_reports
 where author_id=a.user_id and kind='weekly' and deleted_at is null
 and week_start=start_date and week_end=end_date
 order by created_at desc,id desc limit 1
 ) r on true
 where a.role in ('employee','deputy','trainee')
 and exists(select 1 from public.portal_accounts where user_id=(select auth.uid()) and role='commissioner')
 order by a.game_name,a.user_id;
$$;
revoke all on function public.portal_bonus_statement_roster(date,date) from public,anon;
grant execute on function public.portal_bonus_statement_roster(date,date) to authenticated;
