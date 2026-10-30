-- 009 · Red ash surface
-- The city directory lists 15 venues as "Red Ash", the compacted volcanic
-- surface most neighbourhood medas in Addis actually play on. It is neither
-- concrete nor turf, so it gets its own value.
-- Kept in its own migration: Postgres cannot use a new enum value in the
-- transaction that adds it.

alter type public.surface_type add value if not exists 'red_ash';
