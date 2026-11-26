create table public.portal_notifications (
 id bigint generated always as identity primary key,
 recipient_id uuid not null references public.portal_accounts(user_id) on delete cascade,
 kind text not null check (kind in ('weekly','promotion','role')),
 created_at timestamptz not null default now(),
 read_at timestamptz
);
alter table public.portal_notifications enable row level security;
revoke all on public.portal_notifications from anon, authenticated;
grant select on public.portal_notifications to authenticated;
grant update(read_at) on public.portal_notifications to authenticated;
create policy own_portal_notification_read on public.portal_notifications for select to authenticated
 using (recipient_id=(select auth.uid()));
create policy own_portal_notification_mark on public.portal_notifications for update to authenticated
 using (recipient_id=(select auth.uid())) with check (recipient_id=(select auth.uid()));
create index portal_notifications_recipient_idx on public.portal_notifications(recipient_id,id desc);
create function public.portal_notify_report()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
 insert into public.portal_notifications(recipient_id,kind)
 select user_id,new.kind from public.portal_accounts where role in ('commissioner','deputy');
 return new;
end;
$$;
revoke all on function public.portal_notify_report() from public, anon, authenticated;
create trigger portal_report_notification after insert on public.portal_reports
 for each row execute function public.portal_notify_report();
create function public.portal_notify_role()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
 if new.role is not null and new.role is distinct from old.role then
  insert into public.portal_notifications(recipient_id,kind) values(new.user_id,'role');
 end if;
 return new;
end;
$$;
revoke all on function public.portal_notify_role() from public, anon, authenticated;
create trigger portal_role_notification after update of role on public.portal_accounts
 for each row execute function public.portal_notify_role();