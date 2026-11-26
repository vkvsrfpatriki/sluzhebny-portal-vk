alter table public.portal_reports
 add column pdf_base64 text check (pdf_base64 is null or (length(pdf_base64) <= 8000000 and left(pdf_base64, 7) = 'JVBERi0')),
 add column deleted_at timestamptz,
 add column deleted_by uuid;
grant insert (pdf_base64) on public.portal_reports to authenticated;
alter policy read_portal_reports on public.portal_reports
 using (deleted_at is null and (author_id = (select auth.uid()) or (select public.portal_is_leader())));
create index portal_reports_kind_active_idx on public.portal_reports (kind, created_at desc, id desc) where deleted_at is null;
create function public.portal_remove_report(report_id uuid)
returns boolean language plpgsql security definer set search_path = ''
as $$
begin
 if not public.portal_is_leader() then
  raise exception 'Report deletion is not permitted' using errcode = '42501';
 end if;
 update public.portal_reports set deleted_at=now(), deleted_by=auth.uid()
 where id=report_id and deleted_at is null;
 return found;
end;
$$;
revoke all on function public.portal_remove_report(uuid) from public, anon;
grant execute on function public.portal_remove_report(uuid) to authenticated;