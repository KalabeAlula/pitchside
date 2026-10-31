-- 018 · Operators drop exact gate pins
-- The field page's pin picker calls this RPC. Admins already own the field
-- directory (see is_admin and "admins manage pitches"), so the same role
-- decides who may turn an area pin into a gate pin. Routing the write through
-- here keeps the bounds check and the accuracy flag out of client reach.

create or replace function public.set_pitch_pin(
  p_pitch_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns public.pitches
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_pitch public.pitches%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not public.is_admin() then
    raise exception 'only operators can pin fields' using errcode = '42501';
  end if;
  if p_lat is null
     or p_lng is null
     or p_lat not between 8.70 and 9.40
     or p_lng not between 38.40 and 39.20 then
    raise exception 'pin is outside Addis Ababa' using errcode = '45018';
  end if;

  update public.pitches
     set latitude = p_lat,
         longitude = p_lng,
         pin_accuracy = 'exact'
   where id = p_pitch_id
   returning * into v_pitch;

  if not found then
    raise exception 'pitch not found' using errcode = '45000';
  end if;
  return v_pitch;
end;
$$;

comment on function public.set_pitch_pin(uuid, double precision, double precision) is
  'Admin-only: replace a field pin with the operator-verified gate pin.';

revoke all on function public.set_pitch_pin(
  uuid, double precision, double precision
) from public, anon;
grant execute on function public.set_pitch_pin(
  uuid, double precision, double precision
) to authenticated;

-- The first operator is flagged by hand (Supabase dashboard → SQL):
--   update public.profiles set role = 'admin' where id = '<your user id>';
