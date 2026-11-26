create or replace function public.portal_staff_leadership()
returns table(staff_role text, display_name text)
language sql stable security definer set search_path = ''
as $$
 select a.role, coalesce(nullif(trim(a.game_name),''), 'Имя и фамилия не указаны')
 from public.portal_accounts a
 where a.role in ('commissioner','deputy')
 and exists(select 1 from public.portal_accounts viewer where viewer.user_id=(select auth.uid()) and viewer.role is not null)
 order by case a.role when 'commissioner' then 0 else 1 end, a.user_id;
$$;