-- 006 · Write paths (RPCs) + read model
-- Every multi-row operation is one transaction inside Postgres. The Flutter
-- client never sequences inserts itself.

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
  if p_team_size not in (5, 7) then
    raise exception 'team size must be 5 or 7' using errcode = '45014';
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

-- Returns the roster row: member_status tells the client confirmed vs waitlisted.
create or replace function public.join_match(p_match_id uuid)
returns public.match_players
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    uuid := auth.uid();
  v_match  public.matches%rowtype;
  v_status public.member_status;
  v_row    public.match_players%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into v_match from public.matches where id = p_match_id for update;
  if not found then
    raise exception 'match not found' using errcode = '45000';
  end if;
  if v_match.status <> 'scheduled' or v_match.starts_at <= now() then
    raise exception 'match is not open' using errcode = '45002';
  end if;

  if exists (
    select 1 from public.match_players
     where match_id = p_match_id
       and user_id = v_uid
       and member_status in ('confirmed', 'waitlisted')
  ) then
    raise exception 'already on the roster' using errcode = '45006';
  end if;

  v_status := case
                when v_match.current_players < v_match.max_players
                  then 'confirmed'::public.member_status
                else 'waitlisted'::public.member_status
              end;

  insert into public.match_players (match_id, user_id, member_status)
  values (p_match_id, v_uid, v_status)
  on conflict (match_id, user_id) do update
    set member_status = excluded.member_status,
        joined_at     = now()
  returning * into v_row;

  return v_row;
end;
$$;

-- Leaving promotes the longest-waiting player automatically.
create or replace function public.leave_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_match public.matches%rowtype;
  v_next  public.match_players%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into v_match from public.matches where id = p_match_id for update;
  if not found then
    raise exception 'match not found' using errcode = '45000';
  end if;
  if v_match.organizer_id = v_uid then
    raise exception 'the organizer must cancel the match instead of leaving' using errcode = '45007';
  end if;
  if v_match.status <> 'scheduled' then
    raise exception 'match is not open' using errcode = '45002';
  end if;

  update public.match_players
     set member_status = 'left'
   where match_id = p_match_id
     and user_id = v_uid
     and member_status in ('confirmed', 'waitlisted');

  if not found then
    raise exception 'not on the roster' using errcode = '45006';
  end if;

  select * into v_match from public.matches where id = p_match_id;

  if v_match.current_players < v_match.max_players then
    select * into v_next
      from public.match_players
     where match_id = p_match_id
       and member_status = 'waitlisted'
     order by joined_at, user_id
     limit 1
       for update;

    if found then
      update public.match_players
         set member_status = 'confirmed',
             team = public.pick_open_team(p_match_id)
       where match_id = p_match_id
         and user_id = v_next.user_id;
    end if;
  end if;
end;
$$;

create or replace function public.shuffle_teams(p_match_id uuid)
returns void
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

  select * into v_match from public.matches where id = p_match_id;
  if not found then
    raise exception 'match not found' using errcode = '45000';
  end if;
  if v_match.organizer_id <> v_uid then
    raise exception 'only the organizer can shuffle teams' using errcode = '42501';
  end if;
  if v_match.status <> 'scheduled' then
    raise exception 'match is not open' using errcode = '45002';
  end if;

  with ordered as (
    select user_id, row_number() over (order by random()) as rn
      from public.match_players
     where match_id = p_match_id
       and member_status = 'confirmed'
  )
  update public.match_players mp
     set team = case
                  when o.rn % 2 = 1 then 'A'::public.team_side
                  else 'B'::public.team_side
                end
    from ordered o
   where mp.match_id = p_match_id
     and mp.user_id = o.user_id;
end;
$$;

create or replace function public.nearby_pitches(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer default 5000,
  p_limit integer default 30
)
returns table (
  pitch_id       uuid,
  pitch_name     text,
  sub_city_id    text,
  sub_city_name  text,
  address        text,
  latitude       double precision,
  longitude      double precision,
  surface        public.surface_type,
  price_per_hour numeric(10,2),
  distance_m     double precision
)
language sql
stable
as $$
  select q.pitch_id, q.pitch_name, q.sub_city_id, q.sub_city_name, q.address,
         q.latitude, q.longitude, q.surface, q.price_per_hour, q.distance_m
    from (
      select p.id           as pitch_id,
             p.name         as pitch_name,
             p.sub_city_id,
             sc.name_en     as sub_city_name,
             p.address,
             p.latitude,
             p.longitude,
             p.surface,
             p.price_per_hour,
             public.distance_m(p_lat, p_lng, p.latitude, p.longitude) as distance_m
        from public.pitches p
        join public.sub_cities sc on sc.id = p.sub_city_id
       where p.is_active
    ) q
   where q.distance_m <= p_radius_m
   order by q.distance_m
   limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

-- List-screen read model: one round trip, spots_left precomputed.
create or replace view public.match_overview
with (security_invoker = true)
as
select
  m.id,
  m.pitch_id,
  p.name                          as pitch_name,
  p.sub_city_id,
  sc.name_en                      as sub_city_name,
  p.latitude,
  p.longitude,
  m.organizer_id,
  pr.full_name                    as organizer_name,
  m.team_size,
  m.max_players,
  m.current_players,
  (m.max_players - m.current_players) as spots_left,
  m.starts_at,
  m.starts_at + m.duration_minutes * interval '1 minute' as ends_at,
  m.price_per_player,
  m.status,
  m.notes
from public.matches m
join public.pitches p  on p.id = m.pitch_id
join public.sub_cities sc on sc.id = p.sub_city_id
join public.profiles pr on pr.id = m.organizer_id;
