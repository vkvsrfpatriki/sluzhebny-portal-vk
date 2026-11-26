create function public.portal_bonus_roster(start_date date,end_date date)
returns table(employee_name text, submitted boolean, points bigint)
language sql stable security definer set search_path=''
as $$
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
 and exists(select 1 from public.portal_accounts where user_id=(select auth.uid()) and role='commissioner')
 order by a.game_name,a.user_id;
$$;
revoke all on function public.portal_bonus_roster(date,date) from public,anon;
grant execute on function public.portal_bonus_roster(date,date) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit)
values ('portal-materials','portal-materials',false,10485760);
create policy portal_materials_read on storage.objects for select to authenticated
 using (bucket_id='portal-materials' and (storage.foldername(name))[1] in ('documents','training')
 and exists(select 1 from public.portal_accounts where user_id=(select auth.uid()) and role is not null));
create policy portal_materials_upload on storage.objects for insert to authenticated
 with check (bucket_id='portal-materials' and (storage.foldername(name))[1] in ('documents','training')
 and (select public.portal_is_leader()));