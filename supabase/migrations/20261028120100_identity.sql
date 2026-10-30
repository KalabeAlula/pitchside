-- 002 · Player identity
-- auth.users is the identity source; public.profiles carries app-facing data.
-- Phone numbers live in their own table so a roster embed cannot leak every number.

create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  full_name          text not null check (char_length(btrim(full_name)) between 2 and 60),
  sub_city_id        text references public.sub_cities (id) on delete set null,
  level              public.player_level not null default 'beginner',
  avatar_url         text,
  role               public.app_role not null default 'player',
  reliability_rating numeric(3,2) check (reliability_rating between 0 and 5),
  reviews_received   integer not null default 0 check (reviews_received >= 0),
  matches_played     integer not null default 0 check (matches_played >= 0),
  no_shows           integer not null default 0 check (no_shows >= 0),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on column public.profiles.reliability_rating is
  'Null = not rated yet. Maintained by refresh_player_stats(); never written by clients.';

create table public.profile_phones (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  phone      text not null unique check (phone ~ '^\+251[79][0-9]{8}$'),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger profile_phones_set_updated_at
before update on public.profile_phones
for each row execute function public.set_updated_at();

-- Accepts 09xx..., 9xx..., 251xxxxxxxx, "+251 9x xxx xxxx" and returns E.164,
-- or null when the input cannot be a valid Ethiopian mobile number.
create or replace function public.normalize_phone(p_raw text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when d ~ '^0[79][0-9]{8}$'    then '+251' || substr(d, 2)
    when d ~ '^251[79][0-9]{8}$'  then '+' || d
    when d ~ '^[79][0-9]{8}$'     then '+251' || d
  end
  from (select regexp_replace(coalesce(p_raw, ''), '[^0-9]', '', 'g') as d) t;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name     text := left(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), 60);
  v_phone    text := public.normalize_phone(new.raw_user_meta_data ->> 'phone');
  v_sub_city text;
  v_level    public.player_level := 'beginner';
begin
  if char_length(v_name) < 2 then
    v_name := 'Player';
  end if;

  if new.raw_user_meta_data ->> 'sub_city_id' in (select id from public.sub_cities) then
    v_sub_city := new.raw_user_meta_data ->> 'sub_city_id';
  end if;

  if new.raw_user_meta_data ->> 'level' in ('beginner', 'intermediate', 'advanced') then
    v_level := (new.raw_user_meta_data ->> 'level')::public.player_level;
  end if;

  insert into public.profiles (id, full_name, sub_city_id, level)
  values (new.id, v_name, v_sub_city, v_level)
  on conflict (id) do nothing;

  if v_phone is not null then
    insert into public.profile_phones (user_id, phone)
    values (new.id, v_phone)
    on conflict (user_id) do update
      set phone = excluded.phone, updated_at = now();
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
