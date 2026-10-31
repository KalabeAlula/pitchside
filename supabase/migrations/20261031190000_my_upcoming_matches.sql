-- 021 · Upcoming matches
-- The mirror of my_past_matches: the games a player still has to play. The
-- feed drops a game the moment it starts, so the standing page is the way back
-- to a booked game. security_invoker keeps the match and roster RLS in force.

create view public.my_upcoming_matches
with (security_invoker = true) as
select
  m.id,
  m.pitch_id,
  p.name                          as pitch_name,
  sc.name_en                      as sub_city_name,
  m.starts_at,
  m.starts_at + m.duration_minutes * interval '1 minute' as ends_at,
  mp.team
from public.match_players mp
join public.matches m     on m.id = mp.match_id
join public.pitches p     on p.id = m.pitch_id
join public.sub_cities sc on sc.id = p.sub_city_id
where mp.user_id = auth.uid()
  and mp.member_status = 'confirmed'
  and m.status = 'scheduled'
  and m.starts_at > now();

comment on view public.my_upcoming_matches is
  'Scheduled matches where the signed-in player still holds a confirmed spot.';

revoke all on public.my_upcoming_matches from anon;
revoke all on public.my_upcoming_matches from authenticated;
grant select on public.my_upcoming_matches to authenticated;
