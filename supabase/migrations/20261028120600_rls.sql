-- 007 · Row Level Security + column privileges
-- RLS decides *which rows*; column grants decide *which fields*. Both are needed:
-- RLS cannot stop a user updating profiles.reliability_rating on their own row.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and role = 'admin'
  );
$$;

alter table public.sub_cities     enable row level security;
alter table public.profiles       enable row level security;
alter table public.profile_phones enable row level security;
alter table public.pitches        enable row level security;
alter table public.matches        enable row level security;
alter table public.match_players  enable row level security;
alter table public.reviews        enable row level security;

-- ============================ policies ============================

create policy "sub_cities readable by signed-in users"
  on public.sub_cities for select to authenticated
  using (true);

create policy "profiles readable by signed-in users"
  on public.profiles for select to authenticated
  using (true);

create policy "insert own profile"
  on public.profiles for insert to authenticated
  with check (id = auth.uid());

create policy "update own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Phone numbers: yours, plus anyone you have actually been on a roster with.
create policy "phone visible to owner, admins and team-mates"
  on public.profile_phones for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1
        from public.match_players me
        join public.match_players teammate on teammate.match_id = me.match_id
       where me.user_id = auth.uid()
         and teammate.user_id = public.profile_phones.user_id
         and me.member_status = 'confirmed'
         and teammate.member_status = 'confirmed'
    )
  );

create policy "insert own phone"
  on public.profile_phones for insert to authenticated
  with check (user_id = auth.uid());

create policy "update own phone"
  on public.profile_phones for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "pitches readable by signed-in users"
  on public.pitches for select to authenticated
  using (true);

create policy "admins manage pitches"
  on public.pitches for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "matches readable by signed-in users"
  on public.matches for select to authenticated
  using (true);

create policy "organizers update their own match"
  on public.matches for update to authenticated
  using (organizer_id = auth.uid())
  with check (organizer_id = auth.uid());

create policy "rosters readable by signed-in users"
  on public.match_players for select to authenticated
  using (true);

create policy "organizers update their own roster"
  on public.match_players for update to authenticated
  using (
    exists (
      select 1 from public.matches m
       where m.id = match_players.match_id
         and m.organizer_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.matches m
       where m.id = match_players.match_id
         and m.organizer_id = auth.uid()
    )
  );

create policy "players review participants of a match they played"
  on public.reviews for insert to authenticated
  with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.match_players me
       where me.match_id = reviews.match_id
         and me.user_id = auth.uid()
         and me.member_status = 'confirmed'
    )
    and exists (
      select 1 from public.match_players them
       where them.match_id = reviews.match_id
         and them.user_id = reviews.reviewee_id
         and them.member_status = 'confirmed'
    )
  );

create policy "reviews visible to the two people involved"
  on public.reviews for select to authenticated
  using (reviewer_id = auth.uid() or reviewee_id = auth.uid() or public.is_admin());

-- ============================ privileges ============================

-- No anonymous access to any app table.
revoke all on public.sub_cities, public.profiles, public.profile_phones, public.pitches,
              public.matches, public.match_players, public.reviews, public.match_overview
  from anon;

revoke insert, update, delete, truncate on public.sub_cities from authenticated;

-- Writes that must go through RPCs.
revoke insert, delete, truncate on public.matches from authenticated;
revoke insert, delete, truncate on public.match_players from authenticated;
revoke update, delete, truncate on public.reviews from authenticated;
revoke delete on public.profiles, public.profile_phones from authenticated;

-- Reads.
grant select on public.sub_cities, public.profiles, public.profile_phones, public.pitches,
                public.matches, public.match_players, public.reviews
  to authenticated;
grant select on public.match_overview to authenticated;

-- Profile: the user may rename themselves, move sub-city, change level/avatar.
-- role, reliability, matches_played, no_shows, reviews_received are trigger-owned.
revoke insert on public.profiles from authenticated;
revoke update on public.profiles from authenticated;
grant insert (id, full_name, sub_city_id, level, avatar_url) on public.profiles to authenticated;
grant update (full_name, sub_city_id, level, avatar_url) on public.profiles to authenticated;

revoke insert on public.profile_phones from authenticated;
revoke update on public.profile_phones from authenticated;
grant insert (user_id, phone) on public.profile_phones to authenticated;
grant update (phone) on public.profile_phones to authenticated;

-- Match: organizer may reschedule, reprice, annotate, cancel or complete.
-- pitch_id, organizer_id, team_size, current_players are not grantable.
revoke update on public.matches from authenticated;
grant update (starts_at, duration_minutes, price_per_player, notes, status)
  on public.matches to authenticated;

-- Roster: organizer handles team assignment, money and attendance.
-- Joining/leaving goes through join_match()/leave_match().
revoke update on public.match_players from authenticated;
grant update (team, member_status, payment_status, payment_method, payment_ref, paid_at, attended)
  on public.match_players to authenticated;

revoke insert on public.reviews from authenticated;
grant insert (match_id, reviewer_id, reviewee_id, overall, sportsmanship, reliability, comment)
  on public.reviews to authenticated;

-- Functions: only the RPC surface is callable.
revoke execute on all functions in schema public from anon, public;
revoke execute on function public.refresh_player_stats(uuid) from authenticated;
revoke execute on function public.pick_open_team(uuid) from authenticated;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.distance_m(double precision, double precision, double precision, double precision) to authenticated;
grant execute on function public.nearby_pitches(double precision, double precision, integer, integer) to authenticated;
grant execute on function public.create_match(uuid, smallint, timestamptz, smallint, numeric, text) to authenticated;
grant execute on function public.join_match(uuid) to authenticated;
grant execute on function public.leave_match(uuid) to authenticated;
grant execute on function public.shuffle_teams(uuid) to authenticated;
