-- 014 · Leaving a match is timestamped
--
-- The fair-play score needs to know *when* a player gave up a spot: a
-- cancellation inside three hours of kickoff is penalised, an earlier one is
-- not. leave_match() only flipped member_status to 'left' and lost that
-- moment.
--
-- left_from keeps the status the player left from. Dropping a waiting-list
-- place never affects the game, so the future score can ignore those rows and
-- only count confirmed spots.
--
-- join_match() clears both columns when the same player comes back; a stale
-- leave time must not outlive the return.

alter table public.match_players
  add column left_at   timestamptz,
  add column left_from public.member_status
    check (left_from is null or left_from <> 'left');

comment on column public.match_players.left_at is
  'When the player gave up this roster row; null while they hold it.';
comment on column public.match_players.left_from is
  'Status the player left from: confirmed or waitlisted.';

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

  -- left_from reads the old row, before the status flips to 'left'.
  update public.match_players
     set member_status = 'left',
         left_at       = now(),
         left_from     = member_status
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
