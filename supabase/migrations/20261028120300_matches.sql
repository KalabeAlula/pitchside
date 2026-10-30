-- 004 · Matches, rosters, reviews
-- "Open" vs "full" is derived (spots_left), never stored, so it cannot drift.
-- current_players counts confirmed players only and is maintained by trigger.

create table public.matches (
  id               uuid primary key default gen_random_uuid(),
  pitch_id         uuid not null references public.pitches (id) on delete restrict,
  organizer_id     uuid not null references public.profiles (id) on delete restrict,
  team_size        smallint not null check (team_size in (5, 7)),
  max_players      smallint generated always as ((team_size * 2)::smallint) stored,
  current_players  smallint not null default 0,
  starts_at        timestamptz not null,
  duration_minutes smallint not null default 60 check (duration_minutes between 30 and 180),
  price_per_player numeric(10,2) not null default 0 check (price_per_player >= 0),
  status           public.match_status not null default 'scheduled',
  notes            text check (notes is null or char_length(notes) <= 500),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint matches_capacity check (current_players between 0 and team_size * 2)
);

comment on column public.matches.current_players is
  'Confirmed players only; waitlisted players are not counted. Maintained by trigger.';
comment on column public.matches.status is
  'scheduled -> cancelled | completed. No full/open value: derive from max_players - current_players.';

create index matches_starts_at_idx on public.matches (starts_at) where status = 'scheduled';
create index matches_pitch_idx on public.matches (pitch_id);
create index matches_organizer_idx on public.matches (organizer_id);

create table public.match_players (
  match_id       uuid not null references public.matches (id) on delete cascade,
  user_id        uuid not null references public.profiles (id) on delete cascade,
  team           public.team_side,
  member_status  public.member_status not null default 'confirmed',
  payment_status public.payment_status not null default 'unpaid',
  payment_method public.payment_method,
  payment_ref    text,
  paid_at        timestamptz,
  attended       boolean,
  joined_at      timestamptz not null default now(),
  primary key (match_id, user_id),
  constraint match_players_confirmed_has_team
    check (member_status <> 'confirmed' or team is not null)
);

comment on column public.match_players.attended is
  'Null until the organizer marks attendance after kickoff.';

create index match_players_user_idx on public.match_players (user_id);

create table public.reviews (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references public.matches (id) on delete cascade,
  reviewer_id   uuid not null references public.profiles (id) on delete cascade,
  reviewee_id   uuid not null references public.profiles (id) on delete cascade,
  overall       smallint not null check (overall between 1 and 5),
  sportsmanship smallint not null check (sportsmanship between 1 and 5),
  reliability   smallint not null check (reliability between 1 and 5),
  comment       text check (comment is null or char_length(comment) <= 500),
  created_at    timestamptz not null default now(),
  constraint reviews_no_self check (reviewer_id <> reviewee_id),
  constraint reviews_once_per_match unique (match_id, reviewer_id, reviewee_id)
);

create index reviews_reviewee_idx on public.reviews (reviewee_id);
