create function public.portal_review_report_with_reason(report_id uuid, decision text, reason text)
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
 insert into public.portal_notifications(recipient_id,kind) values(recipient,decision);
 return true;
end;
$$;
alter table public.portal_notifications drop constraint portal_notifications_kind_check;
alter table public.portal_notifications add constraint portal_notifications_kind_check check (kind in ('weekly','promotion','role','approved','rejected'));
revoke all on function public.portal_review_report_with_reason(uuid,text,text) from public,anon;
grant execute on function public.portal_review_report_with_reason(uuid,text,text) to authenticated;