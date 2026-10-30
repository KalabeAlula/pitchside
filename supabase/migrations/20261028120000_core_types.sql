-- 001 · Domain types + Addis Ababa reference data
-- Time: timestamptz everywhere. Ethiopia is UTC+3 with no DST.
-- Money: ETB as numeric(10,2) — exact, never float.

create type public.player_level   as enum ('beginner', 'intermediate', 'advanced');
create type public.surface_type   as enum ('artificial_grass', 'natural_grass', 'futsal_court', 'concrete');
create type public.match_status   as enum ('scheduled', 'cancelled', 'completed');
create type public.team_side      as enum ('A', 'B');
create type public.member_status  as enum ('confirmed', 'waitlisted', 'left');
create type public.payment_status as enum ('unpaid', 'pending', 'paid', 'refunded', 'waived');
create type public.payment_method as enum ('cash', 'telebirr', 'chapa', 'bank_transfer');
create type public.app_role       as enum ('player', 'admin');

create table public.sub_cities (
  id      text primary key,
  name_en text not null unique,
  name_am text not null
);

comment on table public.sub_cities is
  'The 11 sub-cities of Addis Ababa. Reference data, not user-editable.';

insert into public.sub_cities (id, name_en, name_am) values
  ('addis-ketema',     'Addis Ketema',     'አዲስ ከተማ'),
  ('akaky-kaliti',     'Akaky Kaliti',     'አቃቂ ቃሊቲ'),
  ('arada',            'Arada',            'አራዳ'),
  ('bole',             'Bole',             'ቦሌ'),
  ('gullele',          'Gullele',          'ጉለሌ'),
  ('kirkos',           'Kirkos',           'ቂርቆስ'),
  ('kolfe-keranio',    'Kolfe Keranio',    'ኮልፌ ቀራንዮ'),
  ('lemi-kura',        'Lemi Kura',        'ለሚ ኩራ'),
  ('lideta',           'Lideta',           'ልደታ'),
  ('nifas-silk-lafto', 'Nifas Silk-Lafto', 'ንፋስ ስልክ ላፍቶ'),
  ('yeka',             'Yeka',             'የካ');
