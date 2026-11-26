create function public.portal_staff_leadership()
returns table(staff_role text, display_name text)
language sql stable security definer set search_path = ''
as $$
 select a.role, left(coalesce(
  nullif(trim(u.raw_user_meta_data->>'full_name'),''),
  nullif(trim(u.raw_user_meta_data->>'name'),''),
  nullif(trim(u.raw_user_meta_data->>'preferred_username'),''),
  'Сотрудник ВК'),80)
 from public.portal_accounts a
 join auth.users u on u.id=a.user_id
 where a.role in ('commissioner','deputy')
 and exists(select 1 from public.portal_accounts viewer where viewer.user_id=(select auth.uid()) and viewer.role is not null)
 order by case a.role when 'commissioner' then 0 else 1 end, a.user_id;
$$;
revoke all on function public.portal_staff_leadership() from public, anon;
grant execute on function public.portal_staff_leadership() to authenticated;