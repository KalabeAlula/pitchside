-- 019 · Field ratings from players who played
-- pitch_reviews existed as read-only furniture: seeded rows, no way in. This
-- opens the one honest path — a player who was marked present at a completed
-- match on that field may rate it, and may edit that same review later. The
-- rule lives in can_review_pitch() so the state read, the write RPC and the
-- RLS policy can never drift apart.

create or replace function public.can_review_pitch(p_pitch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.match_players mp
      join public.matches m on m.id = mp.match_id
     where m.pitch_id = p_pitch_id
       and mp.user_id = auth.uid()
       and mp.member_status = 'confirmed'
       and mp.attended is true
       and m.status = 'completed'
  );
$$;

comment on function public.can_review_pitch(uuid) is
  'True when the caller was marked present at a completed match on this pitch.';

revoke all on function public.can_review_pitch(uuid) from public, anon;
grant execute on function public.can_review_pitch(uuid) to authenticated;

-- One call gives the field page everything it needs: whether to offer the
-- composer, and the caller's existing review to prefill when editing.
create or replace function public.pitch_review_state(p_pitch_id uuid)
returns table (can_review boolean, my_rating smallint, my_comment text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_rating  smallint;
  v_comment text;
begin
  if auth.uid() is null then
    return query select false, null::smallint, null::text;
    return;
  end if;

  select r.rating, r.comment
    into v_rating, v_comment
    from public.pitch_reviews r
   where r.pitch_id = p_pitch_id
     and r.reviewer_id = auth.uid();

  return query select public.can_review_pitch(p_pitch_id), v_rating, v_comment;
end;
$$;

comment on function public.pitch_review_state(uuid) is
  'Field page review gate: can the caller review, and what did they already say?';

-- Create or replace in one statement: the unique (pitch_id, reviewer_id) row
-- means a second submit is an edit, not a duplicate.
create or replace function public.submit_pitch_review(
  p_pitch_id uuid,
  p_rating smallint,
  p_comment text
)
returns public.pitch_reviews
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_comment text := nullif(btrim(coalesce(p_comment, '')), '');
  v_review  public.pitch_reviews%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'rating must be between 1 and 5' using errcode = '22023';
  end if;

  if v_comment is not null and char_length(v_comment) > 500 then
    raise exception 'review is too long' using errcode = '22001';
  end if;

  if not exists (select 1 from public.pitches where id = p_pitch_id) then
    raise exception 'pitch not found' using errcode = '45000';
  end if;

  if not public.can_review_pitch(p_pitch_id) then
    raise exception 'only players who finished a match here can review'
      using errcode = '42501';
  end if;

  insert into public.pitch_reviews (pitch_id, reviewer_id, rating, comment)
  values (p_pitch_id, auth.uid(), p_rating, v_comment)
  on conflict (pitch_id, reviewer_id) do update
     set rating = excluded.rating,
         comment = excluded.comment
  returning * into v_review;

  return v_review;
end;
$$;

comment on function public.submit_pitch_review(uuid, smallint, text) is
  'Player-only: rate a field they finished a match on, editing on repeat calls.';

revoke all on function public.pitch_review_state(uuid) from public, anon;
revoke all on function public.submit_pitch_review(uuid, smallint, text)
  from public, anon;
grant execute on function public.pitch_review_state(uuid) to authenticated;
grant execute on function public.submit_pitch_review(uuid, smallint, text)
  to authenticated;

-- The old insert rule only asked for a confirmed spot after kickoff, so a
-- cancelled match still counted. Replace it with the played-the-match rule,
-- then close the direct write path: reviews now go through the RPC above.
drop policy if exists "players review a pitch they played" on public.pitch_reviews;
create policy "players review a pitch they played"
  on public.pitch_reviews for insert to authenticated
  with check (
    reviewer_id = auth.uid()
    and public.can_review_pitch(pitch_reviews.pitch_id)
  );

drop policy if exists "reviewers edit their own pitch review"
  on public.pitch_reviews;

revoke insert, update on public.pitch_reviews from authenticated;
revoke insert (pitch_id, reviewer_id, rating, comment)
  on public.pitch_reviews from authenticated;
revoke update (rating, comment) on public.pitch_reviews from authenticated;

-- Reviewers can still remove their own review directly; the rest of the
-- select/delete grants are unchanged.
