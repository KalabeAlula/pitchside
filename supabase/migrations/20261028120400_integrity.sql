-- 005 · Integrity: capacity, team balance, counters, reputation
-- All of these are SECURITY DEFINER so they keep working no matter which
-- column-level grants the calling user has.

-- Great-circle distance in metres.
create or replace function public.distance_m(
  p_lat1 double precision,
  p_lng1 double precision,
  p_lat2 double precision,
  p_lng2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2))
      * power(sin(radians(p_lng2 - p_lng1) / 2), 2)
  ));
$$;

-- Side with fewer confirmed players; ties go to A so joins alternate.
create or replace function public.pick_open_team(p_match_id uuid)
returns public.team_side
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when count(*) filter (where team = 'A') <= count(*) filter (where team = 'B')
      then 'A'::public.team_side
    else 'B'::public.team_side
  end
  from public.match_players
  where match_id = p_match_id
    and member_status = 'confirmed';
$$;

-- Single enforcement point for joining: locks the match row, then checks state
-- and capacity. Concurrent joins serialise on the row lock, so the roster can
-- never exceed max_players even without going through join_match().
create or replace function public.match_players_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_match     public.matches%rowtype;
  v_confirmed integer;
begin
  if tg_op = 'UPDATE' then
    if new.match_id <> old.match_id or new.user_id <> old.user_id then
      raise exception 'roster identity is immutable' using errcode = '45012';
    end if;

    -- Already on the roster: payments, attendance, post-match edits. No capacity work.
    if old.member_status = 'confirmed' then
      if new.member_status <> 'confirmed' then
        new.team := null;
      end if;
      return new;
    end if;
  end if;

  select * into v_match from public.matches where id = new.match_id for update;
  if not found then
    raise exception 'match not found' using errcode = '45000';
  end if;
  if v_match.status <> 'scheduled' or v_match.starts_at <= now() then
    raise exception 'match is not open' using errcode = '45002';
  end if;

  if new.member_status = 'confirmed' then
    select count(*) into v_confirmed
      from public.match_players
     where match_id = new.match_id
       and member_status = 'confirmed'
       and user_id <> new.user_id;

    if v_confirmed >= v_match.max_players then
      raise exception 'match is full' using errcode = '45001';
    end if;

    new.team := coalesce(new.team, public.pick_open_team(new.match_id));
  else
    new.team := null;
  end if;

  return new;
end;
$$;

create trigger match_players_guard
before insert or update on public.match_players
for each row execute function public.match_players_guard();

-- Keep matches.current_players in step with the roster.
create or replace function public.sync_match_counts()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_match_id uuid;
begin
  if tg_op = 'DELETE' then
    v_match_id := old.match_id;
  else
    v_match_id := new.match_id;
  end if;

  update public.matches m
     set current_players = (
           select count(*)::smallint
             from public.match_players mp
            where mp.match_id = v_match_id
              and mp.member_status = 'confirmed'
         )
   where m.id = v_match_id;
  return null;
end;
$$;

create trigger match_players_sync_counts
after insert or update or delete on public.match_players
for each row execute function public.sync_match_counts();

-- Reputation is derived, never client-written.
create or replace function public.refresh_player_stats(p_user_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.profiles p
     set matches_played     = s.played,
         no_shows           = s.no_shows,
         reviews_received   = r.cnt,
         reliability_rating = case
                                when r.cnt = 0 then null
                                else round(r.avg_reliability::numeric, 2)
                              end,
         updated_at         = now()
    from (
      select count(*) filter (where mp.attended is true)  as played,
             count(*) filter (where mp.attended is false) as no_shows
        from public.match_players mp
        join public.matches m on m.id = mp.match_id
       where mp.user_id = p_user_id
         and mp.member_status = 'confirmed'
         and m.status = 'completed'
    ) s
    cross join (
      select count(*) as cnt, avg(rv.reliability) as avg_reliability
        from public.reviews rv
       where rv.reviewee_id = p_user_id
    ) r
   where p.id = p_user_id;
$$;

-- Reviews are allowed only between two confirmed players of a completed match.
create or replace function public.reviews_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.matches
     where id = new.match_id and status = 'completed'
  ) then
    raise exception 'reviews open only after the match is completed' using errcode = '45011';
  end if;

  if not exists (
    select 1
      from public.match_players me
      join public.match_players them on them.match_id = me.match_id
     where me.match_id = new.match_id
       and me.user_id = new.reviewer_id
       and them.user_id = new.reviewee_id
       and me.member_status = 'confirmed'
       and them.member_status = 'confirmed'
  ) then
    raise exception 'reviewer and reviewee must both have played' using errcode = '45010';
  end if;

  return new;
end;
$$;

create trigger reviews_guard
before insert on public.reviews
for each row execute function public.reviews_guard();

create or replace function public.reviews_after_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_player_stats(old.reviewee_id);
  else
    perform public.refresh_player_stats(new.reviewee_id);
  end if;
  return null;
end;
$$;

create trigger reviews_refresh_reputation
after insert or update or delete on public.reviews
for each row execute function public.reviews_after_change();

create or replace function public.match_players_after_attendance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.attended is distinct from old.attended then
    perform public.refresh_player_stats(new.user_id);
  end if;
  return null;
end;
$$;

create trigger match_players_track_attendance
after update on public.match_players
for each row execute function public.match_players_after_attendance();

create or replace function public.matches_after_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    perform public.refresh_player_stats(mp.user_id)
      from public.match_players mp
     where mp.match_id = new.id
       and mp.member_status = 'confirmed';
  end if;
  return null;
end;
$$;

create trigger matches_track_status
after update of status on public.matches
for each row execute function public.matches_after_status_change();

-- Matches may not be re-homed, resized, or resurrected.
create or replace function public.matches_guard_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.organizer_id <> old.organizer_id
     or new.pitch_id <> old.pitch_id
     or new.team_size <> old.team_size then
    raise exception 'pitch, organizer and team size are immutable' using errcode = '45013';
  end if;

  if old.status <> 'scheduled' and new.status <> old.status then
    raise exception 'match is closed' using errcode = '45004',
      detail = 'status cannot change from ' || old.status::text;
  end if;

  if new.status = 'completed' and now() < old.starts_at then
    raise exception 'cannot complete a match before kickoff' using errcode = '45005';
  end if;

  return new;
end;
$$;

create trigger matches_guard_update
before update on public.matches
for each row execute function public.matches_guard_update();

create trigger matches_set_updated_at
before update on public.matches
for each row execute function public.set_updated_at();
