alter table public.portal_reports
 add column review_status text not null default 'pending' check (review_status in ('pending','approved','rejected')),
 add column reviewed_at timestamptz,
 add column reviewed_by uuid;

create function public.portal_review_report(report_id uuid, decision text)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
 if not public.portal_is_leader() then
  raise exception 'Report review is not permitted' using errcode='42501';
 end if;
 if decision is null or decision not in ('approved','rejected') then
  raise exception 'Invalid decision' using errcode='22023';
 end if;
 update public.portal_reports set review_status=decision,reviewed_by=auth.uid(),reviewed_at=now()
 where id=report_id and deleted_at is null and review_status='pending';
 return found;
end;
$$;
revoke all on function public.portal_review_report(uuid,text) from public, anon;
grant execute on function public.portal_review_report(uuid,text) to authenticated;

create index portal_approved_week_top_idx on public.portal_reports(week_start,week_end,author_id,created_at desc,id desc)
 where kind='weekly' and review_status='approved' and deleted_at is null;

create function public.portal_weekly_leaderboard(start_date date,end_date date)
returns table(place bigint, name text, points bigint)
language sql stable security definer set search_path=''
as $$
 with selected as (
  select distinct on (r.author_id) r.author_id,r.weekly_points
  from public.portal_reports r
  where r.kind='weekly' and r.review_status='approved' and r.deleted_at is null
   and r.week_start=start_date and r.week_end=end_date and r.weekly_points is not null
   and exists (select 1 from public.portal_accounts viewer where viewer.user_id=(select auth.uid()) and viewer.role is not null)
  order by r.author_id,r.created_at desc,r.id desc
 )
 select rank() over(order by s.weekly_points desc),
  coalesce(nullif(trim(a.game_name),''),'Имя не указано'),s.weekly_points
 from selected s join public.portal_accounts a on a.user_id=s.author_id
 where a.role is not null
 order by s.weekly_points desc,a.game_name,a.user_id;
$$;
revoke all on function public.portal_weekly_leaderboard(date,date) from public, anon;
grant execute on function public.portal_weekly_leaderboard(date,date) to authenticated;