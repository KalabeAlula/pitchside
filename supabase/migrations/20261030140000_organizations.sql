-- 012 · Organizations: companies and clubs arrange their own football
--
-- Public pickup (audience = 'public') is unchanged. Two new audiences:
--   internal  — a company/club game; only members of the host organization
--               can claim a spot, split evenly across the two sides.
--   challenge — the host organization (side A) against another one (side B).
--               The opponent must accept before its players can join.
--
-- The host books (and pays for) the field block when creating the match, so a
-- declined challenge just cancels the match and releases the block.
--
-- Membership is by join code, not by phone or email lookup: profile_phones is
-- readable only by team-mates, and a code lets a manager onboard a whole
-- department without exposing anyone's number.

create type public.org_role       as enum ('owner', 'manager', 'member');
create type public.match_audience as enum ('public', 'internal', 'challenge');

create table public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 2 and 60),
  about       text check (about is null or char_length(about) <= 300),
  sub_city_id text references public.sub_cities (id) on delete set null,
  created_by  uuid not null references public.profiles (id) on delete restrict,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Name collisions would make the challenge picker ambiguous.
create unique index organizations_name_key
  on public.organizations (lower(btrim(name)));

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function public.set_updated_at();

-- The code lives in its own table so the organization directory can be
-- readable by every signed-in player without handing them the join key.
create table public.organization_join_codes (
  org_id     uuid primary key references public.organizations (id) on delete cascade,
  code       text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  created_at timestamptz not null default now()
);

create table public.organization_members (
  org_id    uuid not null references public.organizations (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      public.org_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create index organization_members_user_idx
  on public.organization_members (user_id);

alter table public.matches
  add column organization_id          uuid references public.organizations (id) on delete restrict,
  add column opponent_organization_id uuid references public.organizations (id) on delete restrict,
  add column audience                 public.match_audience not null default 'public',
  add column challenge_accepted_at    timestamptz;

alter table public.matches
  add constraint matches_audience_shape check (
    (audience = 'public'
      and organization_id is null
      and opponent_organization_id is null)
    or (audience = 'internal'
      and organization_id is not null
      and opponent_organization_id is null)
    or (audience = 'challenge'
      and organization_id is not null
      and opponent_organization_id is not null
      and opponent_organization_id <> organization_id)
  );

comment on column public.matches.audience is
  'public = open pickup, internal = host club only, challenge = host club vs opponent club.';
comment on column public.matches.challenge_accepted_at is
  'Set by respond_to_challenge() when the opponent club accepts. Null while pending.';

create index matches_organization_idx
  on public.matches (organization_id) where status = 'scheduled';
create index matches_opponent_organization_idx
  on public.matches (opponent_organization_id) where status = 'scheduled';

-- ============================ helpers ============================

-- No I, O, 0 or 1: a code gets read out loud over the phone.
create or replace function public.generate_join_code()
returns text
language plpgsql
volatile
set search_path = public, pg_temp
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code     text := '';
begin
  for i in 1..6 loop
    v_code := v_code || substr(v_alphabet, 1 + floor(random() * 32)::int, 1);
  end loop;
  return v_code;
end;
$$;

create or replace function public.is_org_member(p_org_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.organization_members
     where org_id = p_org_id
       and user_id = p_user_id
  );
$$;

create or replace function public.is_org_member(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_org_member(p_org_id, auth.uid());
$$;

create or replace function public.can_manage_org(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.organization_members
     where org_id = p_org_id
       and user_id = auth.uid()
       and role in ('owner', 'manager')
  );
$$;

-- ============================ RLS ============================

alter table public.organizations          enable row level security;
alter table public.organization_join_codes enable row level security;
alter table public.organization_members    enable row level security;

create policy "organizations visible to signed-in users"
  on public.organizations for select to authenticated
  using (true);

create policy "managers update their organization"
  on public.organizations for update to authenticated
  using (public.can_manage_org(id))
  with check (public.can_manage_org(id));

create policy "join codes visible to managers"
  on public.organization_join_codes for select to authenticated
  using (public.can_manage_org(org_id) or public.is_admin());

-- Members see who else is in their club; outsiders do not get a staff list.
create policy "members visible inside their organization"
  on public.organization_members for select to authenticated
  using (public.is_org_member(org_id) or public.is_admin());

-- Matches stay readable per audience: public games for everyone, club games
-- only for the clubs involved (and admins).
drop policy "matches readable by signed-in users" on public.matches;

create policy "matches visible to their audience"
  on public.matches for select to authenticated
  using (
    audience = 'public'
    or public.is_org_member(organization_id)
    or (opponent_organization_id is not null
        and public.is_org_member(opponent_organization_id))
    or public.is_admin()
  );

-- ============================ privileges ============================

revoke all on public.organizations, public.organization_join_codes,
              public.organization_members
  from anon;

revoke insert, update, delete, truncate on public.organizations from authenticated;
revoke insert, update, delete, truncate on public.organization_join_codes from authenticated;
revoke insert, update, delete, truncate on public.organization_members from authenticated;

grant select on public.organizations, public.organization_join_codes,
                public.organization_members
  to authenticated;

-- Managers may rename, describe and re-locate their club. Everything else
-- (owner, join code, membership) moves through the RPCs below.
grant update (name, about, sub_city_id) on public.organizations to authenticated;

-- ============================ write path ============================

create or replace function public.create_organization(
  p_name text,
  p_about text default null,
  p_sub_city_id text default null
)
returns public.organizations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid  uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_org  public.organizations%rowtype;
  v_code text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if char_length(v_name) not between 2 and 60 then
    raise exception 'name must be 2-60 characters' using errcode = '45210';
  end if;
  if p_sub_city_id is not null
     and not exists (select 1 from public.sub_cities where id = p_sub_city_id) then
    raise exception 'unknown sub-city' using errcode = '45206';
  end if;

  begin
    insert into public.organizations (name, about, sub_city_id, created_by)
    values (
      v_name,
      nullif(btrim(coalesce(p_about, '')), ''),
      p_sub_city_id,
      v_uid
    )
    returning * into v_org;
  exception when unique_violation then
    raise exception 'an organization with that name already exists'
      using errcode = '45211';
  end;

  loop
    v_code := public.generate_join_code();
    exit when not exists (
      select 1 from public.organization_join_codes where code = v_code
    );
  end loop;

  insert into public.organization_join_codes (org_id, code)
  values (v_org.id, v_code);

  insert into public.organization_members (org_id, user_id, role)
  values (v_org.id, v_uid, 'owner');

  return v_org;
end;
$$;

create or replace function public.join_organization(p_code text)
returns public.organizations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_org public.organizations%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select o.* into v_org
    from public.organizations o
    join public.organization_join_codes c on c.org_id = o.id
   where c.code = upper(btrim(coalesce(p_code, '')));

  if not found then
    raise exception 'that join code is not valid' using errcode = '45212';
  end if;

  if public.is_org_member(v_org.id, v_uid) then
    raise exception 'you are already a member' using errcode = '45213';
  end if;

  insert into public.organization_members (org_id, user_id, role)
  values (v_org.id, v_uid, 'member');

  return v_org;
end;
$$;

create or replace function public.leave_organization(p_org_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid  uuid := auth.uid();
  v_role public.org_role;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select role into v_role
    from public.organization_members
   where org_id = p_org_id
     and user_id = v_uid;

  if not found then
    raise exception 'you are not a member of this organization' using errcode = '45215';
  end if;
  if v_role = 'owner' then
    raise exception 'the owner cannot leave the organization' using errcode = '45214';
  end if;

  delete from public.organization_members
   where org_id = p_org_id
     and user_id = v_uid;
end;
$$;

-- create_match gains the club parameters. Same guard rails as before, plus:
--   * only owners/managers create a match for their club
--   * the opponent is optional (internal game) and must be a different club
--   * a challenge starts unaccepted; the opponent answers via the next RPC
drop function if exists public.create_match(
  uuid, smallint, timestamptz, smallint, numeric, text
);

create or replace function public.create_match(
  p_pitch_id uuid,
  p_team_size smallint,
  p_starts_at timestamptz,
  p_duration_minutes smallint default 60,
  p_price_per_player numeric default 0,
  p_notes text default null,
  p_organization_id uuid default null,
  p_opponent_organization_id uuid default null
)
returns public.matches
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid      uuid := auth.uid();
  v_audience public.match_audience := 'public';
  v_match    public.matches%rowtype;
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

  if p_organization_id is not null then
    if not public.can_manage_org(p_organization_id) then
      raise exception 'only club owners and managers can host'
        using errcode = '45203';
    end if;

    if p_opponent_organization_id is not null then
      if p_opponent_organization_id = p_organization_id then
        raise exception 'a club cannot challenge itself' using errcode = '45207';
      end if;
      if not exists (
        select 1 from public.organizations where id = p_opponent_organization_id
      ) then
        raise exception 'opponent club not found' using errcode = '45207';
      end if;
      v_audience := 'challenge';
    else
      v_audience := 'internal';
    end if;
  elsif p_opponent_organization_id is not null then
    raise exception 'an opponent needs a host club' using errcode = '45207';
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
    (pitch_id, organizer_id, team_size, starts_at, duration_minutes,
     price_per_player, notes, audience, organization_id, opponent_organization_id)
  values
    (p_pitch_id, v_uid, p_team_size, p_starts_at, p_duration_minutes,
     coalesce(p_price_per_player, 0), p_notes, v_audience,
     p_organization_id, p_opponent_organization_id)
  returning * into v_match;

  insert into public.match_players (match_id, user_id, team, member_status)
  values (v_match.id, v_uid, 'A', 'confirmed');

  select * into v_match from public.matches where id = v_match.id;
  return v_match;
end;
$$;

create or replace function public.respond_to_challenge(
  p_match_id uuid,
  p_accept boolean
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

  select * into v_match
    from public.matches
   where id = p_match_id
     for update;

  if not found then
    raise exception 'match not found' using errcode = '45000';
  end if;
  if v_match.audience <> 'challenge' then
    raise exception 'this match is not a challenge' using errcode = '45208';
  end if;
  if v_match.status <> 'scheduled' or v_match.starts_at <= now() then
    raise exception 'match is not open' using errcode = '45002';
  end if;
  if v_match.challenge_accepted_at is not null then
    raise exception 'this challenge was already answered' using errcode = '45209';
  end if;
  if not public.can_manage_org(v_match.opponent_organization_id) then
    raise exception 'only the challenged club can answer' using errcode = '45204';
  end if;

  if p_accept then
    update public.matches
       set challenge_accepted_at = now()
     where id = p_match_id
    returning * into v_match;
  else
    update public.matches
       set status = 'cancelled'
     where id = p_match_id
    returning * into v_match;
  end if;

  return v_match;
end;
$$;

-- ============================ roster rules ============================

-- A club game pins each player to their club's side instead of balancing by
-- headcount, and caps each side at team_size. Public pickup keeps the old
-- behaviour: alternate sides, cap the whole roster at 2 * team_size.
create or replace function public.match_players_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_match       public.matches%rowtype;
  v_confirmed   integer;
  v_side_count  integer;
  v_side        public.team_side;
  v_host_member boolean;
  v_opp_member  boolean;
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
    v_host_member := v_match.organization_id is not null
                     and public.is_org_member(v_match.organization_id, new.user_id);
    v_opp_member  := v_match.audience = 'challenge'
                     and public.is_org_member(v_match.opponent_organization_id, new.user_id);

    if v_match.audience = 'internal' then
      if not v_host_member then
        raise exception 'this match is limited to organization members'
          using errcode = '45201';
      end if;
    elsif v_match.audience = 'challenge' then
      if not v_host_member and not v_opp_member then
        raise exception 'this challenge is limited to the two clubs'
          using errcode = '45201';
      end if;
      if not v_host_member and v_match.challenge_accepted_at is null then
        raise exception 'the challenge has not been accepted yet'
          using errcode = '45202';
      end if;
    end if;

    if v_match.audience = 'public' or v_match.audience = 'internal' then
      select count(*) into v_confirmed
        from public.match_players
       where match_id = new.match_id
         and member_status = 'confirmed'
         and user_id <> new.user_id;

      if v_confirmed >= v_match.max_players then
        raise exception 'match is full' using errcode = '45001';
      end if;

      v_side := coalesce(new.team, public.pick_open_team(new.match_id));
    else
      -- A player who belongs to both clubs plays for the host.
      v_side := case when v_host_member then 'A'::public.team_side
                     else 'B'::public.team_side end;
    end if;

    select count(*) into v_side_count
      from public.match_players
     where match_id = new.match_id
       and member_status = 'confirmed'
       and team = v_side
       and user_id <> new.user_id;

    if v_side_count >= v_match.team_size then
      raise exception 'that team is full' using errcode = '45001';
    end if;

    new.team := v_side;
  else
    new.team := null;
  end if;

  return new;
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
        joined_at     = now()
  returning * into v_row;

  return v_row;
end;
$$;

-- Shuffling a challenge would move players off their club's side.
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
  if v_match.audience = 'challenge' then
    raise exception 'a club challenge keeps players on their club''s side'
      using errcode = '45205';
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

-- Club identity is as immutable as pitch, organizer and team size.
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

  return new;
end;
$$;

-- ============================ read model ============================

drop view public.match_overview;

create view public.match_overview
with (security_invoker = true) as
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
  m.notes,
  m.audience,
  m.organization_id,
  o.name                          as organization_name,
  m.opponent_organization_id,
  opp.name                        as opponent_organization_name,
  m.challenge_accepted_at
from public.matches m
join public.pitches p      on p.id = m.pitch_id
join public.sub_cities sc  on sc.id = p.sub_city_id
join public.profiles pr    on pr.id = m.organizer_id
left join public.organizations o   on o.id = m.organization_id
left join public.organizations opp on opp.id = m.opponent_organization_id;

revoke all on public.match_overview from anon;
grant select on public.match_overview to authenticated;

-- Field availability must count every scheduled match, including club games
-- whose rows the reader cannot see. The function only reveals whether a block
-- is taken, never who booked it.
create or replace function public.pitch_slots(p_pitch_id uuid, p_day date)
returns table (slot_start timestamptz, slot_end timestamptz, is_booked boolean)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select s.slot_start,
         s.slot_start + make_interval(hours => p.booking_block_hours) as slot_end,
         exists (
           select 1
             from public.matches m
            where m.pitch_id = p.id
              and m.status = 'scheduled'
              and m.starts_at < s.slot_start
                  + make_interval(hours => p.booking_block_hours)
              and m.starts_at + make_interval(mins => m.duration_minutes)
                  > s.slot_start
         ) as is_booked
    from public.pitches p
    cross join lateral (
      select (p_day + time '08:00')::timestamp at time zone 'Africa/Addis_Ababa'
             + n * interval '1 hour' as slot_start
        from generate_series(0, 12, p.booking_block_hours::int) as n
    ) s
   where p.id = p_pitch_id
   order by s.slot_start;
$$;

revoke all on function public.pitch_slots(uuid, date) from public, anon;
grant execute on function public.pitch_slots(uuid, date) to authenticated;

-- ============================ function privileges ============================

revoke execute on function public.generate_join_code() from public, anon, authenticated;
revoke execute on function public.is_org_member(uuid, uuid) from public, anon, authenticated;

grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.can_manage_org(uuid) to authenticated;

grant execute on function public.create_organization(text, text, text) to authenticated;
grant execute on function public.join_organization(text) to authenticated;
grant execute on function public.leave_organization(uuid) to authenticated;
grant execute on function public.respond_to_challenge(uuid, boolean) to authenticated;
grant execute on function public.create_match(
  uuid, smallint, timestamptz, smallint, numeric, text, uuid, uuid
) to authenticated;
grant execute on function public.join_match(uuid) to authenticated;
grant execute on function public.leave_match(uuid) to authenticated;
grant execute on function public.shuffle_teams(uuid) to authenticated;
