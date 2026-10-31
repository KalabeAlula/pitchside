-- 017 · Area pins for the field directory
-- The Addis Sport directory publishes a sub-city and woreda, never a gate.
-- Every pin below is therefore area-level, not a verified entrance:
--   · 25 venues resolve to a named locality or place (Bambis, Lebu, Jemo,
--     Kazanchis, African Union, Birimo football field, …) via OpenStreetMap
--     Nominatim.
--   · The other 45 fall back to the centre of their sub-city polygon
--     (geoBoundaries ETH ADM3, ODbL).
-- pin_accuracy records which kind of pin a row carries. The app labels
-- approximate pins so a player knows to confirm the gate, and an exact pin
-- replaces an approximate one without the app pretending otherwise.

alter table public.pitches
  add column if not exists pin_accuracy text
    check (pin_accuracy is null or pin_accuracy in ('exact', 'approximate'));

comment on column public.pitches.pin_accuracy is
  'Provenance of latitude/longitude: exact = operator-supplied gate pin, '
  'approximate = area-level geocode. Null when the row has no pin.';

-- Backfill never touches an exact pin, so this migration stays safe to
-- re-run after operators start supplying gate pins.
update public.pitches p
   set latitude = v.latitude,
       longitude = v.longitude,
       pin_accuracy = 'approximate'
  from (values
    ('Asco Oromia Meda', 'addis-ketema', 9.03568, 38.72739),
    ('Asfaw Meda', 'addis-ketema', 9.03568, 38.72739),
    ('Chaka Meda', 'addis-ketema', 9.03568, 38.72739),
    ('George Nikola Meda', 'addis-ketema', 9.03568, 38.72739),
    ('Kwas Meda', 'addis-ketema', 9.03785, 38.72737),
    ('Ye Medemer Tiwulid Meda', 'addis-ketema', 9.03568, 38.72739),
    ('አማኑኤል ጸበል የስፖርት ማዘውተሪያ ስፍራ', 'addis-ketema', 9.02867, 38.71645),
    ('Arsema Meda', 'akaky-kaliti', 8.89827, 38.80458),
    ('Artificial Meda no.1', 'akaky-kaliti', 8.89827, 38.80458),
    ('Berta Meda', 'akaky-kaliti', 8.89827, 38.80458),
    ('Gelan Condominium Meda', 'akaky-kaliti', 8.88013, 38.76807),
    ('Salo Addis Sefer Meda', 'akaky-kaliti', 8.95687, 38.77155),
    ('Zone 6.4 No.2 Meda', 'akaky-kaliti', 8.89827, 38.80458),
    ('ሩፋኤል አካባቢ', 'akaky-kaliti', 8.89827, 38.80458),
    ('ቀጠና 6.4 ቁጥር 1 ሜዳ ወረዳ 1', 'akaky-kaliti', 8.89827, 38.80458),
    ('በሰቃ ሜዳ ወረዳ 8', 'akaky-kaliti', 8.86892, 38.79088),
    ('አርቲፊሻል ሜዳ ቁ.2', 'akaky-kaliti', 8.89827, 38.80458),
    ('Afencho Ber', 'arada', 9.04475, 38.75625),
    ('Beller Meda', 'arada', 9.03667, 38.75553),
    ('Sanford', 'arada', 9.03667, 38.75553),
    ('Simens', 'arada', 9.03667, 38.75553),
    ('22 Golagul', 'bole', 9.01534, 38.78695),
    ('24 Meda', 'bole', 8.98672, 38.79340),
    ('Bulbula Meda', 'bole', 8.98115, 38.83989),
    ('Rwanda Meda', 'bole', 8.99179, 38.77932),
    ('ለሚ እግር ኳስ ሜዳ', 'bole', 8.98115, 38.83989),
    ('እግዜአብሄር አብ', 'bole', 8.98115, 38.83989),
    ('Addis Birhan Meda', 'gullele', 9.07243, 38.74550),
    ('ማርያም ወንዝ', 'gullele', 9.07243, 38.74550),
    ('ጉለሌ ወረዳ 2 ፉትሳል', 'gullele', 9.07243, 38.74550),
    ('50 Kebele Football Meda', 'kirkos', 9.00212, 38.75928),
    ('Bambis Football Meda', 'kirkos', 9.00987, 38.77199),
    ('Qera Football Meda', 'kirkos', 8.99177, 38.74794),
    ('አፍሪካ ህብረት ፊት ለፊት', 'kirkos', 9.00100, 38.74213),
    ('ካዛንቺስ ስፓርት ለሁሉም', 'kirkos', 9.01593, 38.77122),
    ('ጨርቆስ መሀል አካፋይ 01 እግር ኳስ ሜዳ', 'kirkos', 9.00212, 38.75928),
    ('ጨርቆስ መሀል አካፋይ 02 እግር ኳስ ሜዳ', 'kirkos', 9.00212, 38.75928),
    ('Esat Adega Gon Bethel Rom Meda', 'kolfe-keranio', 9.01104, 38.68790),
    ('Weredaw Gon Melata Meda', 'kolfe-keranio', 9.01104, 38.68790),
    ('Zenebe Werk Medemer Meda', 'kolfe-keranio', 9.01104, 38.68790),
    ('40/60 መሪ ሎቄ', 'lemi-kura', 9.02053, 38.86040),
    ('Ethio China', 'lemi-kura', 8.98919, 38.86062),
    ('Legejila', 'lemi-kura', 9.02715, 38.87828),
    ('ወረዳ 9 ፅ/ቤ - ፊት ሳል', 'lemi-kura', 9.02715, 38.87828),
    ('ዙርያሸ ሞል - ፊትሳል', 'lemi-kura', 9.01547, 38.87161),
    ('ጎሮ ወረዳ 9 ፉት ሳል', 'lemi-kura', 8.99696, 38.83205),
    ('Alemu Meda', 'lideta', 9.02154, 38.73105),
    ('Birimo', 'lideta', 9.00949, 38.73531),
    ('Bisrate Gabriel Area', 'lideta', 9.01251, 38.73060),
    ('Tesfa Meda', 'lideta', 9.01251, 38.73060),
    ('መካኒሳ ( ዘብራ) ሜዳ', 'lideta', 8.97191, 38.73053),
    ('የመደመር ትዉልድ ሜዳ (Gordeme)', 'lideta', 9.01251, 38.73060),
    ('46 sport field', 'nifas-silk-lafto', 8.95315, 38.72973),
    ('Addis Sefer Football Field', 'nifas-silk-lafto', 8.95315, 38.72973),
    ('Arsema', 'nifas-silk-lafto', 8.95315, 38.72973),
    ('Buna Board', 'nifas-silk-lafto', 8.96753, 38.76275),
    ('Gara', 'nifas-silk-lafto', 8.94813, 38.72895),
    ('Jamo', 'nifas-silk-lafto', 8.95315, 38.72973),
    ('Jemo Fana', 'nifas-silk-lafto', 8.95996, 38.71148),
    ('Kerpep', 'nifas-silk-lafto', 8.95315, 38.72973),
    ('Lebu Sports Field', 'nifas-silk-lafto', 8.96114, 38.72542),
    ('Wereda 12 Area', 'nifas-silk-lafto', 8.95315, 38.72973),
    ('Wereda 15', 'nifas-silk-lafto', 8.95315, 38.72973),
    ('11 Football Meda', 'yeka', 9.05000, 38.82804),
    ('28 Football Meda', 'yeka', 9.05000, 38.82804),
    ('Admasiye Football Meda', 'yeka', 9.05000, 38.82804),
    ('Chefe Multipurpose Sports Center', 'yeka', 9.06388, 38.77446),
    ('Medemer Tiwulid', 'yeka', 9.05000, 38.82804),
    ('Woreda 4 Football Field', 'yeka', 9.05000, 38.82804),
    ('Youth Center Futsal', 'yeka', 9.05000, 38.82804)
  ) as v(name, sub_city_id, latitude, longitude)
 where p.name = v.name
   and p.sub_city_id = v.sub_city_id
   and p.pin_accuracy is distinct from 'exact';

-- Replacing an area pin with the real gate is a one-row update. The backfill
-- above skips rows marked exact, so this sticks:
--   update public.pitches
--      set latitude = 9.012345, longitude = 38.765432, pin_accuracy = 'exact'
--    where name = 'Bambis Football Meda' and sub_city_id = 'kirkos';

-- Rebuilt (not replaced) so the card read model exposes the new column.
drop view public.pitch_cards;
create view public.pitch_cards
with (security_invoker = true) as
select p.id, p.name, p.sub_city_id, p.address, p.latitude, p.longitude,
       p.pin_accuracy, p.surface, p.price_per_hour, p.booking_block_hours,
       p.has_floodlights, p.contact_phone, p.image_url, p.woreda,
       p.description, p.amenities, p.house_rules, p.directory_rating,
       p.directory_review_count,
       (select round(avg(r.rating)::numeric, 1)
          from public.pitch_reviews r where r.pitch_id = p.id) as rating_avg,
       (select count(*)
          from public.pitch_reviews r where r.pitch_id = p.id) as review_count
from public.pitches p
where p.is_active;

revoke all on public.pitch_cards from anon;
grant select on public.pitch_cards to authenticated;
