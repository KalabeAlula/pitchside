-- 010 · Real Addis Sport directory + 2-hour booking slots
-- Source: addissport.gov.et/en/fields, scraped 2026-10-30 (73 listings).
-- Imported: 67 football and 3 futsal venues with a published hourly price.
-- Left out: 2 basketball courts and 1 futsal venue with no price, because a
-- venue without a price cannot be booked.
-- The city publishes sub-city and woreda, never a street pin, so coordinates
-- stay null until an operator supplies them.

-- The directory is thinner than the demo fixtures were: no pin, no floodlight
-- flag. Model that as unknown instead of inventing a value.
alter table public.pitches alter column latitude drop not null;
alter table public.pitches alter column longitude drop not null;
alter table public.pitches alter column has_floodlights drop not null;
alter table public.pitches drop constraint pitches_latitude_check;
alter table public.pitches drop constraint pitches_longitude_check;
alter table public.pitches add constraint pitches_latitude_check
  check (latitude is null or latitude between 8.70 and 9.40);
alter table public.pitches add constraint pitches_longitude_check
  check (longitude is null or longitude between 38.40 and 39.20);

-- Every listing prices a 2-hour session (the two-hour figure is exactly twice
-- the hourly one for all 72), so a slot is the booking unit.
alter table public.pitches
  add column booking_block_hours smallint not null default 2
    check (booking_block_hours between 1 and 4),
  add column directory_rating numeric(2,1)
    check (directory_rating is null or directory_rating between 0.1 and 5.0),
  add column directory_review_count integer not null default 0
    check (directory_review_count >= 0);

comment on column public.pitches.booking_block_hours is
  'Slot length sold at this venue. Matches are created inside one block.';
comment on column public.pitches.directory_rating is
  'Aggregate rating published by the Addis Sport city directory at import '
  'time. Player reviews live in public.pitch_reviews and are shown separately.';

-- The hand-written demo venues are retired now that the real directory is in.
-- Matches already booked at them keep resolving; the directory stops listing them.
update public.pitches
   set is_active = false
 where name in (
   'Sarbet Turf House', 'Bole Atlas 5-A-Side', 'Kazanchis Turf', 'Megenagna Green Pitch',
   'CMC Turf Arena', 'Gerji Soccer Park', 'Piassa Turf', 'Gullele Turf Center'
 );

insert into public.pitches (
  name, sub_city_id, address, woreda, description, amenities, house_rules,
  surface, price_per_hour, directory_rating, directory_review_count
) values
  ('Asco Oromia Meda', 'addis-ketema', 'Addis Ketema, Woreda 14', 'Woreda 14',
   'Asco Oromia Meda is a red ash community football field located in Addis Ketema, Wereda 14. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 300.00, null, 0),
  ('Asfaw Meda', 'addis-ketema', 'Addis Ketema, Woreda 10', 'Woreda 10',
   'Asfaw Meda is a community dirt football field located in Addis Ketema, Wereda 10. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 300.00, null, 0),
  ('Chaka Meda', 'addis-ketema', 'Addis Ketema, Woreda 06', 'Woreda 06',
   'Chaka Meda is a community dirt football field located in Addis Ketema, Wereda 6. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 5.0, 2),
  ('George Nikola Meda', 'addis-ketema', 'Addis Ketema, Woreda 13', 'Woreda 13',
   'George Nikola Meda is a modern artificial turf football field located in Addis Ketema, Wereda 13. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Kwas Meda', 'addis-ketema', 'Addis Ketema, Woreda 09', 'Woreda 09',
   'Kwas Meda is a natural grass football field located in Addis Ketema, Wereda 9. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 300.00, null, 0),
  ('Ye Medemer Tiwulid Meda', 'addis-ketema', 'Addis Ketema, Woreda 14', 'Woreda 14',
   'Ye Medemer Tiwulid Meda is a modern artificial turf football field located in Addis Ketema, Wereda 14. Suitable for training, friendly matches, and local competitions. It offers a simple, no-frills playing environment.',
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 250.00, 5.0, 1),
  ('አማኑኤል ጸበል የስፖርት ማዘውተሪያ ስፍራ', 'addis-ketema', 'Addis Ketema, Woreda 04', 'Woreda 04',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 400.00, 1.0, 1),
  ('Arsema Meda', 'akaky-kaliti', 'Akaky Kaliti, Woreda 13', 'Woreda 13',
   'Arsema Meda is a red ash community football field located in Akaki, Wereda 13. Suitable for training, friendly matches, and local competitions. It offers a simple, no-frills playing environment.',
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 200.00, null, 0),
  ('Artificial Meda no.1', 'akaky-kaliti', 'Akaky Kaliti, Woreda 08', 'Woreda 08',
   'Artificial Meda No. 1 is a modern artificial turf football field located in Akaki Kality, Wereda 8. Suitable for training, friendly matches, and local competitions. It offers a simple, no-frills playing environment.',
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 250.00, null, 0),
  ('Berta Meda', 'akaky-kaliti', 'Akaky Kaliti, Woreda 05', 'Woreda 05',
   'Berta Meda is a red ash community football field located in Akaki, Wereda 05. Suitable for training, friendly matches, and local competitions. It includes amenities such as grandstand, shade.',
   array['Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 200.00, null, 0),
  ('Gelan Condominium Meda', 'akaky-kaliti', 'Akaky Kaliti, Woreda 12', 'Woreda 12',
   'Gelan Condominium Meda is a red ash community football field located in Akaki, Wereda 12. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 200.00, null, 0),
  ('Salo Addis Sefer Meda', 'akaky-kaliti', 'Akaky Kaliti, Woreda 12', 'Woreda 12',
   'Salo Addis Sefer Meda is a red ash community football field located in Akaki, Wereda 12. Suitable for training, friendly matches, and local competitions. It offers a simple, no-frills playing environment.',
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 200.00, null, 0),
  ('Zone 6.4 No.2 Meda', 'akaky-kaliti', 'Akaky Kaliti, Woreda 13', 'Woreda 13',
   'Zone 6.4 No.2 Meda is a red ash community football field located in Akaki, Wereda 13. Suitable for training, friendly matches, and local competitions. It offers a simple, no-frills playing environment.',
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 200.00, null, 0),
  ('ሩፋኤል አካባቢ', 'akaky-kaliti', 'Akaky Kaliti, Woreda 13', 'Woreda 13',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 250.00, null, 0),
  ('ቀጠና 6.4 ቁጥር 1 ሜዳ ወረዳ 1', 'akaky-kaliti', 'Akaky Kaliti, Woreda 01', 'Woreda 01',
   'Zone 6.4 No.1 Meda is a red ash community football field located in Akaki, Wereda 1. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 250.00, null, 0),
  ('በሰቃ ሜዳ ወረዳ 8', 'akaky-kaliti', 'Akaky Kaliti, Woreda 08', 'Woreda 08',
   'Beseka Meda Wereda 8 is a natural grass football field located in Akaki, Wereda 8. Suitable for training, friendly matches, and local competitions. It offers a simple, no-frills playing environment.',
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'natural_grass', 250.00, null, 0),
  ('አርቲፊሻል ሜዳ ቁ.2', 'akaky-kaliti', 'Akaky Kaliti, Woreda 08', 'Woreda 08',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 250.00, null, 0),
  ('Afencho Ber', 'arada', 'Arada, Woreda 05', 'Woreda 05',
   'Afencho Ber is a modern artificial turf football field located in Arada, Wereda 05. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.5, 4),
  ('Beller Meda', 'arada', 'Arada, Woreda 07', 'Woreda 07',
   'Beller Meda is a modern artificial turf football field located in Arada, Wereda 7. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 1.4, 5),
  ('Sanford', 'arada', 'Arada, Woreda 07', 'Woreda 07',
   'Sanford is a modern artificial turf football field located in Arada, Wereda 7. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Simens', 'arada', 'Arada, Woreda 02', 'Woreda 02',
   'Simen is a modern artificial turf football field located in Arada, Wereda 02. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 3.0, 1),
  ('22 Golagul', 'bole', 'Bole, Woreda 04', 'Woreda 04',
   '22 Golagul is a modern artificial turf football field located in Bole, Wereda 04. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.9, 10),
  ('24 Meda', 'bole', 'Bole, Woreda 05', 'Woreda 05',
   '24 Meda is a modern artificial turf football field located in Bole, Wereda 5. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.8, 4),
  ('Bulbula Meda', 'bole', 'Bole, Woreda 12', 'Woreda 12',
   'Bulbula Meda is a modern artificial turf football field located in Bole, Wereda 12. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 5.0, 1),
  ('Rwanda Meda', 'bole', 'Bole, Woreda 02', 'Woreda 02',
   'Rwanda Meda is a modern artificial turf football field located in Bole, Wereda 2. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 5.0, 1),
  ('ለሚ እግር ኳስ ሜዳ', 'bole', 'Bole, Woreda 14', 'Woreda 14',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('እግዜአብሄር አብ', 'bole', 'Bole, Woreda 06', 'Woreda 06',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 2.0, 1),
  ('Addis Birhan Meda', 'gullele', 'Gullele, Woreda 04', 'Woreda 04',
   'Addis Birhan Meda is a red ash community football field located in Gullele, Wereda 4. Suitable for training, friendly matches, and local competitions. It includes amenities such as grandstand, shade.',
   array['Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 200.00, 5.0, 1),
  ('ማርያም ወንዝ', 'gullele', 'Gullele, Woreda 06', 'Woreda 06',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'natural_grass', 500.00, 3.5, 8),
  ('ጉለሌ ወረዳ 2 ፉትሳል', 'gullele', 'Gullele, Woreda 02', 'Woreda 02',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('50 Kebele Football Meda', 'kirkos', 'Kirkos, Woreda 03', 'Woreda 03',
   '50 Kebele Football Meda is a modern artificial turf football field located in Kirkos, Wereda 3. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Bambis Football Meda', 'kirkos', 'Kirkos, Woreda 01', 'Woreda 01',
   'Bambis Football Meda is a modern artificial turf football field located in Kirkos, Wereda 1. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.6, 12),
  ('Qera Football Meda', 'kirkos', 'Kirkos, Woreda 05', 'Woreda 05',
   'Qera Football Meda is a modern artificial turf football field located in Kirkos, Wereda 5. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('አፍሪካ ህብረት ፊት ለፊት', 'kirkos', 'Kirkos, Woreda 05', 'Woreda 05',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 350.00, 5.0, 3),
  ('ካዛንቺስ ስፓርት ለሁሉም', 'kirkos', 'Kirkos, Woreda 08', 'Woreda 08',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.4, 23),
  ('ጨርቆስ መሀል አካፋይ 01 እግር ኳስ ሜዳ', 'kirkos', 'Kirkos, Woreda 11', 'Woreda 11',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 400.00, null, 0),
  ('ጨርቆስ መሀል አካፋይ 02 እግር ኳስ ሜዳ', 'kirkos', 'Kirkos, Woreda 11', 'Woreda 11',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 400.00, null, 0),
  ('Esat Adega Gon Bethel Rom Meda', 'kolfe-keranio', 'Kolfe Keranio, Woreda 07', 'Woreda 07',
   'Esat Adega Gon Bethel Rom Meda is a red ash community football field located in Kolfe, Wereda 7. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 300.00, null, 0),
  ('Weredaw Gon Melata Meda', 'kolfe-keranio', 'Kolfe Keranio, Woreda 10', 'Woreda 10',
   'Weredaw Gon Melata Meda is a modern artificial turf football field located in Kolfe, Wereda 10. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Zenebe Werk Medemer Meda', 'kolfe-keranio', 'Kolfe Keranio, Woreda 05', 'Woreda 05',
   'Zenebe Werk Medemer Meda is a modern artificial turf football field located in Kolfe, Wereda 5. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('40/60 መሪ ሎቄ', 'lemi-kura', 'Lemi Kura, Woreda 10', 'Woreda 10',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 5.0, 2),
  ('Ethio China', 'lemi-kura', 'Lemi Kura, Woreda 05', 'Woreda 05',
   'Ethio China is a natural grass football field located in Lemi Kura, Wereda 5. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'natural_grass', 500.00, null, 0),
  ('Legejila', 'lemi-kura', 'Lemi Kura, Woreda 13', 'Woreda 13',
   'Legejila is a natural grass football field located in Lemi Kura, Wereda 13. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'natural_grass', 500.00, null, 0),
  ('ወረዳ 9 ፅ/ቤ - ፊት ሳል', 'lemi-kura', 'Lemi Kura, Woreda 09', 'Woreda 09',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 200.00, null, 0),
  ('ዙርያሸ ሞል - ፊትሳል', 'lemi-kura', 'Lemi Kura, Woreda 10', 'Woreda 10',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 3.6, 5),
  ('ጎሮ ወረዳ 9 ፉት ሳል', 'lemi-kura', 'Lemi Kura, Woreda 09', 'Woreda 09',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.3, 10),
  ('Alemu Meda', 'lideta', 'Lideta, Woreda 03', 'Woreda 03',
   'Alemu Meda is a red ash community football field located in Lideta, Wereda 3. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Birimo', 'lideta', 'Lideta, Woreda 10', 'Woreda 10',
   'Birimo is a modern artificial turf football field located in Lideta, Wereda 10. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.0, 1),
  ('Bisrate Gabriel Area', 'lideta', 'Lideta, Woreda 08', 'Woreda 08',
   'Bisrate Gabriel Area is a natural grass football field located in Lideta, Wereda 8. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 3.5, 2),
  ('Tesfa Meda', 'lideta', 'Lideta, Woreda 04', 'Woreda 04',
   'Tesfa Meda is a modern artificial turf football field located in Lideta, Wereda 4. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('መካኒሳ ( ዘብራ) ሜዳ', 'lideta', 'Lideta, Woreda 08', 'Woreda 08',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('የመደመር ትዉልድ ሜዳ (Gordeme)', 'lideta', 'Lideta, Woreda 07', 'Woreda 07',
   'Gordeme is a modern artificial turf football field located in Lideta, Wereda 7. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.5, 2),
  ('46 sport field', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 06', 'Woreda 06',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Addis Sefer Football Field', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 09', 'Woreda 09',
   'Addis Sefer Football Field is a modern artificial turf football field located in Nifas Silk, Wereda 09. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Arsema', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 13', 'Woreda 13',
   'Arsema is a modern artificial turf football field located in Nifas Silk, Wereda 13. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.7, 3),
  ('Buna Board', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 07', 'Woreda 07',
   'Buna Board is a red ash community football field located in Nifas Silk, Wereda 7. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 300.00, null, 0),
  ('Gara', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 01', 'Woreda 01',
   'Gara is a modern artificial turf football field located in Nifas Silk, Wereda 1. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 5.0, 2),
  ('Jamo', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 13', 'Woreda 13',
   'Jamo is a red ash community football field located in Nifas Silk, Wereda 13. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 300.00, 5.0, 1),
  ('Jemo Fana', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 13', 'Woreda 13',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 4.5, 11),
  ('Kerpep', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 12', 'Woreda 12',
   'Kerpep is a natural grass football field located in Nifas Silk, Wereda 12. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'natural_grass', 500.00, null, 0),
  ('Lebu Sports Field', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 01', 'Woreda 01',
   'Lebu Sports Field is a modern artificial turf football field located in Nifas Silk, Wereda 1. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 5.0, 3),
  ('Wereda 12 Area', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 12', 'Woreda 12',
   'Wereda 12 Area is a modern artificial turf football field located in Nifas Silk, Wereda 12. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet.',
   array['Shower', 'Toilet'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, null, 0),
  ('Wereda 15', 'nifas-silk-lafto', 'Nifas Silk-Lafto, Woreda 15', 'Woreda 15',
   'Wereda 15 is a modern artificial turf football field located in Nifas Silk, Wereda 15. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, disability access.',
   array['Shower', 'Toilet', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 3.5, 2),
  ('11 Football Meda', 'yeka', 'Yeka, Woreda 08', 'Woreda 08',
   '11 Football Meda is a natural grass football field located in Yeka, Wereda 8. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, disability access.',
   array['Shower', 'Toilet', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'natural_grass', 400.00, null, 0),
  ('28 Football Meda', 'yeka', 'Yeka, Woreda 06', 'Woreda 06',
   '28 Football Meda is a modern artificial turf football field located in Yeka, Wereda 6. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, disability access.',
   array['Shower', 'Toilet', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 500.00, 5.0, 1),
  ('Admasiye Football Meda', 'yeka', 'Yeka, Woreda 12', 'Woreda 12',
   'Admasiye Football Meda is a red ash community football field located in Yeka, Wereda 12. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, disability access.',
   array['Shower', 'Toilet', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'red_ash', 250.00, null, 0),
  ('Chefe Multipurpose Sports Center', 'yeka', 'Yeka, Woreda 01', 'Woreda 01',
   'Chefe Multipurpose Sports Center is a natural grass football field located in Yeka, Wereda 1. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, grandstand, shade, disability access.',
   array['Shower', 'Toilet', 'Grandstand', 'Shaded area', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'natural_grass', 500.00, null, 0),
  ('Medemer Tiwulid', 'yeka', 'Yeka, Woreda 01', 'Woreda 01',
   'Medemer Tiwulid is a modern artificial turf football field located in Yeka, Wereda 1. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, disability access.',
   array['Shower', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 400.00, null, 0),
  ('Woreda 4 Football Field', 'yeka', 'Yeka, Woreda 04', 'Woreda 04',
   null,
   '{}', array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 400.00, null, 0),
  ('Youth Center Futsal', 'yeka', 'Yeka, Woreda 07', 'Woreda 07',
   'Youth Center Futsal is a modern artificial turf football field located in Yeka, Wereda 7. Suitable for training, friendly matches, and local competitions. It includes amenities such as shower, toilet, disability access.',
   array['Shower', 'Toilet', 'Disability access'], array['Arrive 15 minutes before your slot', 'Respect the referee and venue staff', 'No smoking inside the playing area', 'Carry your rubbish with you'], 'artificial_grass', 400.00, null, 0)

on conflict (name, sub_city_id) do update
  set address               = excluded.address,
      woreda                = excluded.woreda,
      description           = excluded.description,
      amenities             = excluded.amenities,
      house_rules           = excluded.house_rules,
      surface               = excluded.surface,
      price_per_hour        = excluded.price_per_hour,
      directory_rating      = excluded.directory_rating,
      directory_review_count = excluded.directory_review_count,
      is_active             = true;

-- Rebuilt rather than replaced: the city rating and block length are new
-- columns and CREATE OR REPLACE VIEW can only append them.
drop view public.pitch_cards;
create view public.pitch_cards
with (security_invoker = true) as
select p.id, p.name, p.sub_city_id, p.address, p.latitude, p.longitude,
       p.surface, p.price_per_hour, p.booking_block_hours, p.has_floodlights,
       p.contact_phone, p.image_url, p.woreda, p.description, p.amenities,
       p.house_rules, p.directory_rating, p.directory_review_count,
       (select round(avg(r.rating)::numeric, 1)
          from public.pitch_reviews r where r.pitch_id = p.id) as rating_avg,
       (select count(*)
          from public.pitch_reviews r where r.pitch_id = p.id) as review_count
from public.pitches p
where p.is_active;

revoke all on public.pitch_cards from anon;
grant select on public.pitch_cards to authenticated;

-- ---- slots -------------------------------------------------------------
-- The day grid a field sells: whole blocks from 08:00 Addis time. A block is
-- booked when any scheduled match overlaps it.
create index if not exists matches_pitch_window_idx
  on public.matches (pitch_id, starts_at)
  where status = 'scheduled';

create or replace function public.pitch_slots(p_pitch_id uuid, p_day date)
returns table (slot_start timestamptz, slot_end timestamptz, is_booked boolean)
language sql
stable
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

comment on function public.pitch_slots(uuid, date) is
  'Bookable blocks for one field on one Addis calendar day.';

revoke all on function public.pitch_slots(uuid, date) from public, anon;
grant execute on function public.pitch_slots(uuid, date) to authenticated;

-- ---- no double booking ------------------------------------------------
-- create_match gains an overlap check under a per-field advisory lock. The
-- lock is what makes the check safe: two organizers racing for the same block
-- queue instead of both reading "free".
create or replace function public.create_match(
  p_pitch_id uuid,
  p_team_size smallint,
  p_starts_at timestamptz,
  p_duration_minutes smallint default 60,
  p_price_per_player numeric default 0,
  p_notes text default null
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
  if p_team_size not in (5, 7) then
    raise exception 'team size must be 5 or 7' using errcode = '45014';
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
    (pitch_id, organizer_id, team_size, starts_at, duration_minutes, price_per_player, notes)
  values
    (p_pitch_id, v_uid, p_team_size, p_starts_at, p_duration_minutes,
     coalesce(p_price_per_player, 0), p_notes)
  returning * into v_match;

  insert into public.match_players (match_id, user_id, team, member_status)
  values (v_match.id, v_uid, 'A', 'confirmed');

  select * into v_match from public.matches where id = v_match.id;
  return v_match;
end;
$$;
