-- 003 · Pitches (turf venues)
-- Lat/lng is the source of truth; distance math is in-database (haversine) so no
-- PostGIS dependency is needed at this scale (hundreds of pitches, sub-millisecond scans).

create table public.pitches (
  id              uuid primary key default gen_random_uuid(),
  name            text not null check (char_length(btrim(name)) between 2 and 80),
  sub_city_id     text not null references public.sub_cities (id),
  address         text,
  latitude        double precision not null check (latitude between 8.70 and 9.40),
  longitude       double precision not null check (longitude between 38.40 and 39.20),
  surface         public.surface_type not null default 'artificial_grass',
  price_per_hour  numeric(10,2) not null check (price_per_hour >= 0),
  has_floodlights boolean not null default true,
  contact_phone   text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint pitches_name_per_sub_city unique (name, sub_city_id)
);

comment on column public.pitches.latitude is 'WGS84. Checked against the Greater Addis bounding box.';

create index pitches_sub_city_idx on public.pitches (sub_city_id);

create trigger pitches_set_updated_at
before update on public.pitches
for each row execute function public.set_updated_at();
