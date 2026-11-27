create or replace function public.portal_save_profile(target_user uuid, player_name text, player_rank text, player_static text, player_position text)
returns void language plpgsql security definer set search_path = ''
as $$
declare
 actor uuid := auth.uid();
 prior jsonb;
 updated jsonb;
begin
 if actor is null or not exists (
  select 1 from public.portal_accounts where user_id = actor and role is not null
 ) or (target_user is distinct from actor and not public.portal_is_leader()) then
  raise exception 'Profile editing is not permitted' using errcode = '42501';
 end if;
 player_name := trim(coalesce(player_name, ''));
 player_rank := trim(coalesce(player_rank, ''));
 player_static := trim(coalesce(player_static, ''));
 player_position := trim(coalesce(player_position, ''));
 if char_length(player_name) not between 1 and 100 or
    char_length(player_rank) > 80 or
    char_length(player_static) not between 1 and 40 or char_length(player_position) > 100 then
  raise exception 'Invalid profile fields' using errcode = '22023';
 end if;
 select jsonb_build_object('name',game_name,'rank',game_rank,'static',game_static,'position',game_position)
 into prior from public.portal_accounts where user_id=target_user and role is not null for update;
 if not found then raise exception 'Profile not found'; end if;
 if target_user=actor and not public.portal_is_leader() then
  player_rank := prior->>'rank';
 end if;
 updated := jsonb_build_object('name',player_name,'rank',player_rank,'static',player_static,'position',player_position);
 if prior = updated then return; end if;
 update public.portal_accounts set game_name=player_name, game_rank=player_rank,
  game_static=player_static, game_position=player_position where user_id=target_user;
 insert into public.portal_profile_log(target_id,editor_id,previous_values,new_values) values (target_user,actor,prior,updated);
end;
$$;
revoke all on function public.portal_save_profile(uuid,text,text,text,text) from public, anon;
grant execute on function public.portal_save_profile(uuid,text,text,text,text) to authenticated;


alter table public.portal_reports add column weekly_breakdown jsonb, add column review_reason text;
create table public.portal_weekly_rates(id text primary key,title text not null,rate integer not null check(rate>=0),senior boolean not null default false);
alter table public.portal_weekly_rates enable row level security;
revoke all on public.portal_weekly_rates from anon,authenticated;
insert into public.portal_weekly_rates values
('16','Организация ГМП (3 и более организаций, минимум по 5 сотрудников)',100,false),
('6','Организация и проведение экзамена',50,false),
('12','Экскурсия по ВЧ',50,false),
('14','Проведение внутрифракционного мероприятия',50,false),
('15','Участие в ГМП (3 и более организаций, минимум по 5 сотрудников)',50,false),
('17','Агитационная стойка (1 час)',50,false),
('7','Участие в призыве',35,false),
('3','Проведение тренировки (минимум 2 человека)',3,false),
('11','Проведение лекции (минимум 1 человек)',30,false),
('5','Успешное отбитие КРаЗа',25,false),
('13','Участие в вечерней поверке',25,false),
('1','Участие в поставке',20,false),
('2','Участие в отбитии (ВС, ОБ7, РЛС)',20,false),
('4','Участие в отбитии КРаЗа',20,false),
('8','Рассмотрение рапорта военнослужащего из Военной академии',20,false),
('18','Принять экзамен ВА',20,false),
('9','Обработка человека по электронным заявкам',15,false),
('10','Приведение к присяге',15,false),
('procedure','Передать проц. действия правоохранительным органам',10,false),
('academyOath','Принятие присяги у ВА',1,false),
('thanks','Благодарность от руководства',0,false),
('dismissal','Уволил военнослужащего',15,true),
('enlistment','Принял граждан на службу',15,true),
('promote','Повысил военнослужащих',10,true);
create function public.portal_submit_weekly(report_id uuid, report_body text, report_pdf text, start_date date,end_date date, actions jsonb)
returns void language plpgsql security definer set search_path=''
as $$
declare
 actor uuid := auth.uid();
 points bigint;
 breakdown jsonb;
 rank_name text;
begin
 select lower(trim(game_rank)) into rank_name from public.portal_accounts where user_id=actor and role is not null;
 if not found then raise exception 'Access denied' using errcode='42501'; end if;
 if exists(select 1 from public.portal_reports where id=report_id and author_id=actor and kind='weekly') then return; end if;
 if start_date is null or end_date is distinct from start_date+6 or extract(isodow from start_date)<>1 or
 jsonb_typeof(actions) is distinct from 'object' then raise exception 'Invalid weekly report' using errcode='22023'; end if;
 if exists(select 1 from jsonb_each_text(actions) j left join public.portal_weekly_rates r on r.id=j.key
 where r.id is null or j.value is null or j.value !~ '^[1-9][0-9]{0,5}$' or
 (r.senior and rank_name not in ('капитан','майор','подполковник','полковник','генерал-майор','генерал-лейтенант','генерал-полковник','генерал армии','маршал российской федерации'))) then
 raise exception 'Invalid action or rank' using errcode='22023'; end if;
 select coalesce(sum(j.value::bigint*r.rate),0),coalesce(jsonb_agg(jsonb_build_object('title',r.title,'count',j.value::integer,'points',j.value::bigint*r.rate) order by r.title),'[]')
 into points,breakdown from jsonb_each_text(actions) j join public.portal_weekly_rates r on r.id=j.key;
 insert into public.portal_reports(id,author_id,kind,body,pdf_base64,week_start,week_end,weekly_points,weekly_breakdown)
 values(report_id,actor,'weekly',report_body,report_pdf,start_date,end_date,points,breakdown);
end;
$$;
revoke all on function public.portal_submit_weekly(uuid,text,text,date,date,jsonb) from public,anon;
grant execute on function public.portal_submit_weekly(uuid,text,text,date,date,jsonb) to authenticated;
