alter table public.portal_notifications add column related_report_id uuid references public.portal_reports(id) on delete set null, add column reminder_week date;
alter table public.portal_notifications drop constraint portal_notifications_kind_check;
alter table public.portal_notifications add constraint portal_notifications_kind_check check (kind in ('weekly','promotion','role','approved','rejected','weekly_reminder'));
create unique index portal_weekly_reminder_once_idx on public.portal_notifications(recipient_id,reminder_week) where kind='weekly_reminder';
create or replace function public.portal_review_report_with_reason(report_id uuid, decision text, reason text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare recipient uuid;
begin
 if decision='rejected' and coalesce(length(trim(reason)),0) not between 1 and 500 then
  raise exception 'Rejection reason required' using errcode='22023';
 end if;
 if not public.portal_review_report(report_id,decision) then return false; end if;
 update public.portal_reports set review_reason=case when decision='rejected' then trim(reason) end
 where id=report_id returning author_id into recipient;
 insert into public.portal_notifications(recipient_id,kind,related_report_id) values(recipient,decision,report_id);
 return true;
end;
$$;

create or replace function public.portal_notify_report()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 insert into public.portal_notifications(recipient_id,kind,related_report_id)
 select user_id,new.kind,new.id from public.portal_accounts where role in ('commissioner','deputy');
 return new;
end;
$$;
create function public.portal_send_weekly_reminders(start_date date, recipients uuid[])
returns integer language plpgsql security definer set search_path=''
as $$
declare sent integer;
begin
 if not public.portal_is_leader() then raise exception 'Access denied' using errcode='42501';end if;
 if start_date is null or extract(isodow from start_date)<>1 then raise exception 'Invalid week';end if;
 insert into public.portal_notifications(recipient_id,kind,reminder_week)
 select r.employee_id,'weekly_reminder',start_date
 from public.portal_weekly_submission_roster(start_date,start_date+6) r
 join public.portal_accounts a on a.user_id=r.employee_id
 where r.report_id is null and a.role in ('trainee','employee','deputy') and r.employee_id=any(recipients)
 on conflict (recipient_id,reminder_week) where kind='weekly_reminder' do nothing;
 get diagnostics sent = row_count;
 return sent;
end;
$$;
revoke all on function public.portal_send_weekly_reminders(date,uuid[]) from public,anon;
grant execute on function public.portal_send_weekly_reminders(date,uuid[]) to authenticated;
create function public.portal_bonus_statement_details(start_date date,end_date date)
returns table(employee_name text, submitted boolean, points bigint, report_id uuid, review_status text, latest_status text)
language sql stable security definer set search_path=''
as $$
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
 and exists(select 1 from public.portal_accounts where user_id=(select auth.uid()) and role='commissioner')
 order by a.game_name,a.user_id;
$$;
revoke all on function public.portal_bonus_statement_details(date,date) from public,anon;
grant execute on function public.portal_bonus_statement_details(date,date) to authenticated;
