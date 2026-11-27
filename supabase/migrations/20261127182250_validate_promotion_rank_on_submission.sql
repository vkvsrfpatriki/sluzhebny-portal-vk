alter policy submit_portal_reports on public.portal_reports
with check (
 kind = 'promotion'
 and author_id = (select auth.uid())
 and exists (
  select 1 from public.portal_accounts as account
  cross join (values (array[
   'рядовой','ефрейтор','младший сержант','сержант','старший сержант','старшина',
   'прапорщик','старший прапорщик','младший лейтенант','лейтенант','старший лейтенант','капитан'
  ])) as ranks(ordered)
  where account.user_id = (select auth.uid()) and account.role is not null
   and array_position(ranks.ordered, lower(trim(form_data->'fields'->>'requestedRank'))) >= 4
   and array_position(ranks.ordered, lower(trim(form_data->'fields'->>'requestedRank')))
     > array_position(ranks.ordered, lower(trim(account.game_rank)))
 )
);
