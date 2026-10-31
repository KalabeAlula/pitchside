-- 020 · Past matches
-- The public feed drops a game the moment it ends, so this view is the way back
-- to a player's own history. It narrows to the caller's confirmed seats at
-- completed matches; security_invoker keeps the match and roster RLS in force.

create view public.my_past_matches
with (security_invoker = true) as
select
  m.id,
  m.pitch_id,
  p.name                          as pitch_name,
  sc.name_en                      as sub_city_name,
  m.starts_at,
  m.starts_at + m.duration_minutes * interval '1 minute' as ends_at,
  mp.team,
  mp.attended
from public.match_players mp
join public.matches m     on m.id = mp.match_id
join public.pitches p     on p.id = m.pitch_id
join public.sub_cities sc on sc.id = p.sub_city_id
where mp.user_id = auth.uid()
  and mp.member_status = 'confirmed'
  and m.status = 'completed';

comment on view public.my_past_matches is
  'Completed matches where the signed-in player held a confirmed spot.';

revoke all on public.my_past_matches from anon;
revoke all on public.my_past_matches from authenticated;
grant select on public.my_past_matches to authenticated;
