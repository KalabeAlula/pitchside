-- 013 · Verified attendance and match completion
--
-- Reliability scoring needs two facts the app could not record yet: who
-- actually turned up, and when the match was closed. Attendance is the
-- organizer's verification, so both RPCs are organizer-only and open only
-- after kickoff.
--
-- Flow: mark_attendance() records present/no-show for every confirmed player,
-- then complete_match() closes the match. Completion refuses to run while any
-- confirmed player is still unmarked, so nobody's record is silently skipped.
-- The same precondition is enforced in matches_guard_update(), which covers a
-- direct status update through the table's column grants.
--
-- Attendance stays editable until completion; mark_attendance() can be called
-- again to correct a mistaken tap. Each change refreshes the player's stats.

create or replace function public.matches_guard_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.organizer_id <> old.organizer_id
     or new.pitch_id <> old.pitch_id
     or new.team_size <> old.team_size
     or new.organization_id is distinct from old.organization_id
     or new.opponent_organization_id is distinct from old.opponent_organization_id
     or new.audience <> old.audience then
    raise exception 'pitch, organizer, team size and club are immutable'
      using errcode = '45013';
  end if;

  if old.status <> 'scheduled' and new.status <> old.status then
    raise exception 'match is closed' using errcode = '45004',
      detail = 'status cannot change from ' || old.status::text;
  end if;

  if new.status = 'completed' and now() < old.starts_at then
    raise exception 'cannot complete a match before kickoff' using errcode = '45005';
  end if;

  if new.status = 'completed' and old.status is distinct from 'completed'
     and exists (
       select 1
         from public.match_players mp
        where mp.match_id = new.id
          and mp.member_status = 'confirmed'
          and mp.attended is null
     ) then
    raise exception 'mark attendance for every confirmed player before completing'
      using errcode = '45021';
  end if;

  return new;
end;
$$;

-- Records the organizer's roll call. Every confirmed player is set present or
-- absent in one statement; the absence list is whatever is not passed.
create or replace function public.mark_attendance(
  p_match_id uuid,
  p_present_user_ids uuid[]
)
returns table (present_count smallint, absent_count smallint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_match   public.matches%rowtype;
  v_unknown integer;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_present_user_ids is null then
    raise exception 'pass the present players explicitly' using errcode = '45020';
  end if;

  select * into v_match
    from public.matches
   where id = p_match_id
     for update;

  if not found then
    raise exception 'match not found' using errcode = '45000';
  end if;

  if v_match.organizer_id <> v_uid then
    raise exception 'only the organizer can mark attendance' using errcode = '45017';
  end if;

  if v_match.status <> 'scheduled' then
    raise exception 'attendance is closed for this match' using errcode = '45004',
      detail = 'status is ' || v_match.status::text;
  end if;

  if now() < v_match.starts_at then
    raise exception 'attendance opens at kickoff' using errcode = '45018';
  end if;

  select count(*) into v_unknown
    from unnest(p_present_user_ids) as ids(user_id)
   where not exists (
     select 1
       from public.match_players mp
      where mp.match_id = p_match_id
        and mp.user_id = ids.user_id
        and mp.member_status = 'confirmed'
   );

  if v_unknown > 0 then
    raise exception 'attendance can only be marked for confirmed players'
      using errcode = '45019',
      detail = v_unknown || ' id(s) are not on the confirmed roster';
  end if;

  update public.match_players mp
     set attended = (mp.user_id = any (p_present_user_ids))
   where mp.match_id = p_match_id
     and mp.member_status = 'confirmed';

  return query
    select (count(*) filter (where mp.attended))::smallint,
           (count(*) filter (where not mp.attended))::smallint
      from public.match_players mp
     where mp.match_id = p_match_id
       and mp.member_status = 'confirmed';
end;
$$;

-- Closes the match once the roll call is complete. The status trigger then
-- refreshes matches_played / no_shows for every confirmed player.
create or replace function public.complete_match(p_match_id uuid)
returns public.matches
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_match   public.matches%rowtype;
  v_missing integer;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into v_match
    from public.matches
   where id = p_match_id
     for update;

  if not found then
    raise exception 'match not found' using errcode = '45000';
  end if;

  if v_match.organizer_id <> v_uid then
    raise exception 'only the organizer can complete the match' using errcode = '45017';
  end if;

  if v_match.status <> 'scheduled' then
    raise exception 'match is closed' using errcode = '45004',
      detail = 'status is ' || v_match.status::text;
  end if;

  if now() < v_match.starts_at then
    raise exception 'cannot complete a match before kickoff' using errcode = '45005';
  end if;

  select count(*) into v_missing
    from public.match_players mp
   where mp.match_id = p_match_id
     and mp.member_status = 'confirmed'
     and mp.attended is null;

  if v_missing > 0 then
    raise exception 'mark attendance for every confirmed player before completing'
      using errcode = '45021',
      detail = v_missing || ' player(s) still unmarked';
  end if;

  update public.matches
     set status = 'completed'
   where id = p_match_id;

  select * into v_match from public.matches where id = p_match_id;
  return v_match;
end;
$$;

revoke all on function public.mark_attendance(uuid, uuid[]) from public, anon;
revoke all on function public.complete_match(uuid) from public, anon;

grant execute on function public.mark_attendance(uuid, uuid[]) to authenticated;
grant execute on function public.complete_match(uuid) to authenticated;
