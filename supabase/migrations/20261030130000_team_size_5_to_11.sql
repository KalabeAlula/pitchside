-- 011 · Team sizes from 5v5 up to 11v11
-- The directory's fields are hired by the block, and organizers run anything
-- from five-a-side to full-pitch games. Widen the stored range and the RPC
-- guard together so the form and the database cannot disagree.

alter table public.matches
  drop constraint if exists matches_team_size_check;

alter table public.matches
  add constraint matches_team_size_check check (team_size between 5 and 11);

comment on column public.matches.team_size is
  'Players per side, 5 to 11. max_players is derived as team_size * 2.';

-- Same body as 010, with the widened guard and the overlap check kept.
create or replace function public.create_match(
  p_pitch_id uuid,
  p_team_size smallint,
  p_starts_at timestamptz,
  p_duration_minutes smallint default 60,
  p_price_per_player numeric default 0,
  p_notes text default null
)
returns public.matches
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_match public.matches%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_team_size not between 5 and 11 then
    raise exception 'team size must be 5-11' using errcode = '45014';
  end if;
  if p_duration_minutes not between 30 and 180 then
    raise exception 'duration must be 30-180 minutes' using errcode = '45015';
  end if;
  if p_starts_at <= now() then
    raise exception 'kickoff must be in the future' using errcode = '45008';
  end if;
  if not exists (select 1 from public.pitches where id = p_pitch_id and is_active) then
    raise exception 'pitch not found or inactive' using errcode = '45000';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_pitch_id::text, 0));

  if exists (
    select 1
      from public.matches m
     where m.pitch_id = p_pitch_id
       and m.status = 'scheduled'
       and m.starts_at < p_starts_at + make_interval(mins => p_duration_minutes)
       and m.starts_at + make_interval(mins => m.duration_minutes) > p_starts_at
  ) then
    raise exception 'slot already booked' using errcode = '45016';
  end if;

  insert into public.matches
    (pitch_id, organizer_id, team_size, starts_at, duration_minutes, price_per_player, notes)
  values
    (p_pitch_id, v_uid, p_team_size, p_starts_at, p_duration_minutes,
     coalesce(p_price_per_player, 0), p_notes)
  returning * into v_match;

  insert into public.match_players (match_id, user_id, team, member_status)
  values (v_match.id, v_uid, 'A', 'confirmed');

  select * into v_match from public.matches where id = v_match.id;
  return v_match;
end;
$$;
