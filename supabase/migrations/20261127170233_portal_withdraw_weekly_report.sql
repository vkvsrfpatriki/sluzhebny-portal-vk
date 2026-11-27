create or replace function public.portal_withdraw_weekly_report(report_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
 actor uuid := auth.uid();
begin
 if actor is null then return false; end if;

 update public.portal_reports as report
 set deleted_at = now(), deleted_by = actor
 where report.id = report_id
   and report.author_id = actor
   and report.kind = 'weekly'
   and report.review_status = 'pending'
   and report.deleted_at is null
   and exists (select 1 from public.portal_accounts where user_id = actor and role is not null);

 if not found then return false; end if;

 delete from public.portal_notifications
 where related_report_id = report_id and kind = 'weekly';
 return true;
end;
$function$;

revoke all on function public.portal_withdraw_weekly_report(uuid) from public, anon;
grant execute on function public.portal_withdraw_weekly_report(uuid) to authenticated;
