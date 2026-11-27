alter table public.portal_reports add column form_data jsonb
 check (form_data is null or (
  jsonb_typeof(form_data) = 'object'
  and jsonb_typeof(form_data->'fields') is not distinct from 'object'
  and jsonb_typeof(form_data->'entries') is not distinct from 'object'
  and octet_length(form_data::text) <= 300000
 ));

grant insert (form_data) on public.portal_reports to authenticated;

create function public.portal_submit_weekly_with_form(
 report_id uuid, report_body text, report_pdf text, start_date date, end_date date,
 actions jsonb, form_data jsonb
)
returns void language plpgsql security definer set search_path = ''
as $$
begin
 perform public.portal_submit_weekly(report_id,report_body,report_pdf,start_date,end_date,actions);

 update public.portal_reports as report
 set form_data = $7
 where report.id = report_id and report.author_id = auth.uid()
  and report.kind = 'weekly' and report.form_data is null;
end;
$$;

revoke all on function public.portal_submit_weekly_with_form(uuid,text,text,date,date,jsonb,jsonb)
 from public, anon, authenticated;
grant execute on function public.portal_submit_weekly_with_form(uuid,text,text,date,date,jsonb,jsonb)
 to authenticated;
