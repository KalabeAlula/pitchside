-- 008 · Field directory
-- Pitches stop being bare coordinates: the directory needs a photo, a
-- neighbourhood label, an about paragraph, amenities and house rules, plus an
-- aggregate field rating. Match reviews stay player-to-player; these are reviews
-- of the venue itself.

alter table public.pitches
  add column image_url   text check (image_url is null or image_url ~* '^https?://'),
  add column woreda      text check (woreda is null or char_length(btrim(woreda)) between 1 and 60),
  add column description text check (description is null or char_length(description) <= 600),
  add column amenities   text[] not null default '{}',
  add column house_rules text[] not null default '{}';

comment on column public.pitches.image_url is
  'Public photo URL. Null means the app shows bundled field artwork.';
comment on column public.pitches.woreda is
  'Neighbourhood shown under the field name, e.g. "Woreda 04".';
comment on column public.pitches.amenities is
  'Display labels only; order is preserved.';

create table public.pitch_reviews (
  id          uuid primary key default gen_random_uuid(),
  pitch_id    uuid not null references public.pitches (id) on delete cascade,
  reviewer_id uuid not null references public.profiles (id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text check (comment is null or char_length(comment) <= 500),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint pitch_reviews_once_per_player unique (pitch_id, reviewer_id)
);

create index pitch_reviews_pitch_idx on public.pitch_reviews (pitch_id);

create trigger pitch_reviews_set_updated_at
before update on public.pitch_reviews
for each row execute function public.set_updated_at();

alter table public.pitch_reviews enable row level security;

-- Only someone who has actually played a match that has already kicked off at
-- the venue may rate it.
create policy "players review a pitch they played"
  on public.pitch_reviews for insert to authenticated
  with check (
    reviewer_id = auth.uid()
    and exists (
      select 1
        from public.match_players mp
        join public.matches m on m.id = mp.match_id
       where m.pitch_id = pitch_reviews.pitch_id
         and mp.user_id = auth.uid()
         and mp.member_status = 'confirmed'
         and m.starts_at < now()
    )
  );

create policy "pitch reviews readable by signed-in users"
  on public.pitch_reviews for select to authenticated
  using (true);

create policy "reviewers edit their own pitch review"
  on public.pitch_reviews for update to authenticated
  using (reviewer_id = auth.uid())
  with check (reviewer_id = auth.uid());

create policy "reviewers delete their own pitch review"
  on public.pitch_reviews for delete to authenticated
  using (reviewer_id = auth.uid());

-- Directory read model: one row per active pitch with its rating folded in, so
-- the feed is a single request instead of a client-side join.
create view public.pitch_cards
with (security_invoker = true) as
select
  p.id,
  p.name,
  p.sub_city_id,
  p.address,
  p.latitude,
  p.longitude,
  p.surface,
  p.price_per_hour,
  p.has_floodlights,
  p.contact_phone,
  p.image_url,
  p.woreda,
  p.description,
  p.amenities,
  p.house_rules,
  (select round(avg(r.rating)::numeric, 1)
     from public.pitch_reviews r
    where r.pitch_id = p.id) as rating_avg,
  (select count(*)
     from public.pitch_reviews r
    where r.pitch_id = p.id) as review_count
from public.pitches p
where p.is_active;

revoke all on public.pitch_reviews from anon;
grant select on public.pitch_reviews to authenticated;
revoke insert, update, delete, truncate on public.pitch_reviews from authenticated;
grant insert (pitch_id, reviewer_id, rating, comment) on public.pitch_reviews to authenticated;
grant update (rating, comment) on public.pitch_reviews to authenticated;
grant delete on public.pitch_reviews to authenticated;

revoke all on public.pitch_cards from anon;
grant select on public.pitch_cards to authenticated;

-- ============================ venue copy ============================
-- Backfills the seeded Addis pitches. Fields added later get their copy from
-- the operator UI, so this is a one-time content migration.

update public.pitches p
set woreda      = v.woreda,
    description = v.description,
    amenities   = v.amenities,
    house_rules = v.house_rules
from (values
  ('Sarbet Turf House', 'nifas-silk-lafto', 'Woreda 02',
   'A full-size artificial turf pitch tucked behind Sarbet, five minutes off the Ring Road. Popular for evening 7v7 games, with floodlights that stay on until 10pm.',
   array['Floodlights', 'Changing room', 'Shower', 'Parking', 'Bibs & balls'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff', 'No smoking in the playing area']),
  ('Bole Atlas 5-A-Side', 'bole', 'Woreda 03',
   'Five-a-side turf in the middle of Atlas, walking distance from Atlas Hotel. The surface is fast, the walls keep the ball in play, and the crowd makes it feel like a cup final.',
   array['Floodlights', 'Changing room', 'Shower', 'Wifi', 'Cafe'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff', 'No smoking in the playing area']),
  ('Kazanchis Turf', 'kirkos', 'Woreda 08',
   'A compact turf pitch near the ECA roundabout, easy to reach from Kazanchis and Bole. Good for quick after-work 5v5 when the office lets you out late.',
   array['Floodlights', 'Shower', 'Parking', 'Bibs & balls'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff']),
  ('Megenagna Green Pitch', 'bole', 'Woreda 12',
   'Seven-a-side turf off the CMC road with a wide playing area and shaded benches along the touchline. Weeknight slots fill early, so book a day ahead.',
   array['Floodlights', 'Shaded area', 'Changing room', 'Shower', 'Parking'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff', 'No smoking in the playing area']),
  ('CMC Turf Arena', 'yeka', 'Woreda 05',
   'A roomy artificial pitch in CMC with a proper warm-up area and a small stand for spectators. A favourite for weekend 7v7 tournaments.',
   array['Floodlights', 'Grandstand', 'Changing room', 'Shower', 'Parking', 'Cafe'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff', 'No smoking in the playing area']),
  ('Gerji Soccer Park', 'bole', 'Woreda 06',
   'Neighbourhood turf in Gerji Mebrat Hail with open sides and a relaxed atmosphere. Daytime games are the best value in the area.',
   array['Changing room', 'Parking', 'Bibs & balls'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff']),
  ('Piassa Turf', 'arada', 'Woreda 01',
   'An enclosed futsal court steps from St. George, made for tight 5v5 football. The boards keep play moving and the surface is quick underfoot.',
   array['Floodlights', 'Changing room', 'Shower', 'Bibs & balls'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff', 'No smoking in the playing area']),
  ('Gullele Turf Center', 'gullele', 'Woreda 04',
   'A quiet pitch on the Wingate road with roomy sidelines and easy parking. Good for early morning games before the traffic builds.',
   array['Changing room', 'Parking', 'Shaded area'],
   array['Arrive 15 minutes before your slot', 'No metal studs on turf', 'Respect the referee and staff'])
) as v(name, sub_city_id, woreda, description, amenities, house_rules)
where p.name = v.name
  and p.sub_city_id = v.sub_city_id;
