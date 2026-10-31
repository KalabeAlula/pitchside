-- 015 · Fair play: reliability score and suspensions
--
-- Every player starts at 100. A confirmed spot given up inside three hours of
-- kickoff costs 25, and so does a verified no-show. The score is derived from
-- those events, so corrections move it back: rejoining a match you left, or
-- the organizer fixing a roll call, removes the penalty it caused.
--
-- Crossing below 50 opens a seven-day suspension from public pickups. The
-- window starts at the offence, is never extended by later recomputes, and
-- ends on its own. Club games (internal and challenges) are not blocked.
--
-- profiles.reliability_rating is left alone; it is the 0-5 star average from
-- player reviews, a different signal.

alter table public.profiles
  add column reliability_score smallint not null default 100
    check (reliability_score between 0 and 100),
  add column suspended_until timestamptz;

comment on column public.profiles.reliability_score is
  '0-100 fair-play score, derived by refresh_reliability(); clients cannot write it.';
comment on column public.profiles.suspended_until is
  'Public pickups are closed until this instant after dropping below 50.';

-- Recomputes both columns from the player's match history. Suspension is set
-- only when the score crosses below 50 (previous stored score was 50+), so a
-- recompute never silently extends an existing ban.
create or replace function public.refresh_reliability(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_late    integer;
  v_no_show integer;
  v_score   smallint;
  v_old     smallint;
  v_until   timestamptz;
begin
  select count(*) into v_late
    from public.match_players mp
    join public.matches m on m.id = mp.match_id
   where mp.user_id = p_user_id
     and mp.member_status = 'left'
     and mp.left_from = 'confirmed'
     and m.status <> 'cancelled'
     and mp.left_at >= m.starts_at - interval '3 hours';

  select count(*) into v_no_show
    from public.match_players mp
    join public.matches m on m.id = mp.match_id
   where mp.user_id = p_user_id
     and mp.member_status = 'confirmed'
     and mp.attended = false
     and m.status = 'completed';

  v_score := greatest(0, 100 - 25 * (v_late + v_no_show))::smallint;

  select reliability_score, suspended_until
    into v_old, v_until
    from public.profiles
   where id = p_user_id;

  if not found then
    return;
  end if;

  update public.profiles
     set reliability_score = v_score,
         suspended_until = case
           when v_score < 50 and v_old >= 50 then now() + interval '7 days'
           when v_score >= 50 then null
           else v_until
         end,
         updated_at = now()
   where id = p_user_id;
end;
$$;

revoke execute on function public.refresh_reliability(uuid)
  from public, anon, authenticated;

-- Attendance changes move the no-show count, whether they come from
-- mark_attendance() or a direct organizer edit.
create or replace function public.match_players_after_attendance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.attended is distinct from old.attended then
    perform public.refresh_player_stats(new.user_id);
    perform public.refresh_reliability(new.user_id);
  end if;
  return null;
end;
$$;

-- Leaving, rejoining or restoring a roster row moves the late-cancel count.
create or replace function public.match_players_after_left()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.member_status is distinct from old.member_status
     or new.left_at is distinct from old.left_at
     or new.left_from is distinct from old.left_from then
    perform public.refresh_reliability(new.user_id);
  end if;
  return null;
end;
$$;

drop trigger if exists match_players_track_left on public.match_players;
create trigger match_players_track_left
after update on public.match_players
for each row execute function public.match_players_after_left();

-- Completing counts the no-shows just marked; cancelling wipes the penalties
-- of a match that never happened, including for players who had already left.
create or replace function public.matches_after_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status is distinct from old.status then
    perform public.refresh_player_stats(mp.user_id)
      from public.match_players mp
     where mp.match_id = new.id
       and mp.member_status = 'confirmed';

    perform public.refresh_reliability(mp.user_id)
      from public.match_players mp
     where mp.match_id = new.id;
  end if;
  return null;
end;
$$;

-- Suspended players may still play for their club; public pickups wait.
create or replace function public.join_match(p_match_id uuid)
returns public.match_players
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid        uuid := auth.uid();
  v_match      public.matches%rowtype;
  v_status     public.member_status;
  v_row        public.match_players%rowtype;
  v_until      timestamptz;
  v_host_member boolean;
  v_opp_member  boolean;
  v_room        boolean;
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

  if v_match.audience = 'public' then
    select suspended_until into v_until
      from public.profiles
     where id = v_uid;

    if v_until is not null and v_until > now() then
      raise exception 'reliability suspension blocks public games'
        using errcode = '45022',
        detail = 'suspended until ' || v_until::text;
    end if;
  end if;

  v_host_member := v_match.organization_id is not null
                   and public.is_org_member(v_match.organization_id, v_uid);
  v_opp_member  := v_match.audience = 'challenge'
                   and public.is_org_member(v_match.opponent_organization_id, v_uid);

  if v_match.audience = 'internal' and not v_host_member then
    raise exception 'this match is limited to organization members'
      using errcode = '45201';
  end if;
  if v_match.audience = 'challenge' then
    if not v_host_member and not v_opp_member then
      raise exception 'this challenge is limited to the two clubs'
        using errcode = '45201';
    end if;
    if not v_host_member and v_match.challenge_accepted_at is null then
      raise exception 'the challenge has not been accepted yet'
        using errcode = '45202';
    end if;
  end if;

  if exists (
    select 1 from public.match_players
     where match_id = p_match_id
       and user_id = v_uid
       and member_status in ('confirmed', 'waitlisted')
  ) then
    raise exception 'already on the roster' using errcode = '45006';
  end if;

  if v_match.audience = 'challenge' then
    v_room := (
      select count(*) < v_match.team_size
        from public.match_players mp
       where mp.match_id = p_match_id
         and mp.member_status = 'confirmed'
         and mp.team = case when v_host_member
                            then 'A'::public.team_side
                            else 'B'::public.team_side end
    );
  else
    v_room := v_match.current_players < v_match.max_players;
  end if;

  v_status := case
                when v_room then 'confirmed'::public.member_status
                else 'waitlisted'::public.member_status
              end;

  insert into public.match_players (match_id, user_id, member_status)
  values (p_match_id, v_uid, v_status)
  on conflict (match_id, user_id) do update
    set member_status = excluded.member_status,
        joined_at     = now(),
        left_at       = null,
        left_from     = null
  returning * into v_row;

  return v_row;
end;
$$;

-- Score the existing history once, under the same crossing rule.
do $$
declare
  v_profile uuid;
begin
  for v_profile in select id from public.profiles loop
    perform public.refresh_reliability(v_profile);
  end loop;
end;
$$;
