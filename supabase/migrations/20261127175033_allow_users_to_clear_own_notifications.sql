grant delete on public.portal_notifications to authenticated;

create policy own_portal_notification_delete
on public.portal_notifications
for delete
to authenticated
using (recipient_id = (select auth.uid()));
