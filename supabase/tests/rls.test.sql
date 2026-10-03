-- Row-level security and schema tests. Runs in one transaction and rolls back.
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls.test.sql
-- Any failed assertion raises and stops the script with a non-zero exit code.

\set QUIET on
\o /dev/null

begin;

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
end;
$$;

create function pg_temp.act_as_anon() returns void language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
end;
$$;

create function pg_temp.act_as_service() returns void language plpgsql as $$
begin
  perform set_config('role', 'service_role', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
end;
$$;

create function pg_temp.check(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is not true then
    raise exception 'FAIL: %', label;
  end if;
  raise notice 'ok - %', label;
end;
$$;

-- Runs a statement and asserts it raises (any error class).
create function pg_temp.check_fails(stmt text, label text) returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    raise notice 'ok - % (%)', label, sqlerrm;
    return;
  end;
  raise exception 'FAIL: % (statement succeeded)', label;
end;
$$;

grant execute on all functions in schema pg_temp to anon, authenticated, service_role;

-- Fixtures ------------------------------------------------------------------

insert into auth.users (id, email, aud, role)
values
  ('00000000-0000-0000-0000-00000000000a', 'alice@example.com', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@example.com', 'authenticated', 'authenticated');

-- Catalog: RLS on every public table ------------------------------------------

select pg_temp.check(
  not exists (
    select 1 from pg_tables where schemaname = 'public' and not rowsecurity
  ),
  'every table in public has row-level security enabled'
);

select pg_temp.check(
  (select count(*) from pg_tables where schemaname = 'public'
     and tablename in ('songs', 'recordings', 'notation_sections', 'jobs', 'pdfs')) = 5,
  'all five PRD tables exist'
);

select pg_temp.check(
  (select count(*) from storage.buckets where id in ('recordings', 'pdfs') and not public) = 2,
  'recordings and pdfs buckets exist and are private'
);

-- Alice creates her data ----------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');

insert into public.songs (id, title, instrument, capo)
values ('10000000-0000-0000-0000-000000000001', 'Morning Light', 'guitar', 2);

select pg_temp.check(
  (select user_id from public.songs where id = '10000000-0000-0000-0000-000000000001')
    = '00000000-0000-0000-0000-00000000000a',
  'songs.user_id defaults to the signed-in user'
);

select pg_temp.check(
  (select time_signature from public.songs where id = '10000000-0000-0000-0000-000000000001') = '4/4'
  and (select listen_enabled from public.songs where id = '10000000-0000-0000-0000-000000000001'),
  'songs defaults: time_signature 4/4, listen_enabled true'
);

insert into public.recordings (song_id, audio_path)
values ('10000000-0000-0000-0000-000000000001', 'recordings/a/1/take.webm');

insert into public.jobs (id, song_id, type)
values ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'process');

select pg_temp.check_fails(
  $$insert into public.songs (title, instrument, user_id)
    values ('Forged', 'piano', '00000000-0000-0000-0000-00000000000b')$$,
  'a user cannot create a song owned by someone else'
);

select pg_temp.check_fails(
  $$insert into public.jobs (song_id, type, status)
    values ('10000000-0000-0000-0000-000000000001', 'process', 'done')$$,
  'a user cannot create a job in a non-queued state'
);

select pg_temp.check_fails(
  $$insert into public.jobs (song_id, type, cost_usd)
    values ('10000000-0000-0000-0000-000000000001', 'process', 0)$$,
  'a user cannot set job cost'
);

update public.jobs set status = 'done' where id = '30000000-0000-0000-0000-000000000001';
select pg_temp.check(
  (select status from public.jobs where id = '30000000-0000-0000-0000-000000000001') = 'queued',
  'a user cannot move their own job along'
);

update public.recordings set vocal_stem_path = 'x' where song_id = '10000000-0000-0000-0000-000000000001';
select pg_temp.check(
  (select vocal_stem_path from public.recordings
     where song_id = '10000000-0000-0000-0000-000000000001') is null,
  'a user cannot write recording stem paths'
);

select pg_temp.check_fails(
  $$insert into public.notation_sections (song_id, start_s, end_s, kind)
    values ('10000000-0000-0000-0000-000000000001', 0, 8, 'instrumental')$$,
  'a user cannot create notation sections (worker only)'
);

select pg_temp.check_fails(
  $$insert into public.pdfs (song_id, pdf_path)
    values ('10000000-0000-0000-0000-000000000001', 'pdfs/x.pdf')$$,
  'a user cannot create pdf rows (worker only)'
);

-- Storage: own folder only.
insert into storage.objects (bucket_id, name, owner)
values ('recordings', '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/take.webm',
        '00000000-0000-0000-0000-00000000000a');

select pg_temp.check_fails(
  $$insert into storage.objects (bucket_id, name)
    values ('recordings', '00000000-0000-0000-0000-00000000000b/x/take.webm')$$,
  'a user cannot upload into another user''s recordings folder'
);

select pg_temp.check_fails(
  $$insert into storage.objects (bucket_id, name)
    values ('pdfs', '00000000-0000-0000-0000-00000000000a/x/y.pdf')$$,
  'a user cannot upload PDFs (worker only)'
);

-- Worker writes ---------------------------------------------------------------

select pg_temp.act_as_service();

insert into public.notation_sections (id, song_id, label, start_s, end_s, kind)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Intro', 0, 8, 'instrumental');

insert into public.pdfs (song_id, pdf_path)
values ('10000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/p.pdf');

update public.jobs set status = 'running', stage = 'normalizing', progress = 5
where id = '30000000-0000-0000-0000-000000000001';

select pg_temp.check(
  (select count(*) from public.songs) >= 1,
  'service role sees all songs'
);

-- Alice edits notation sections -------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');

update public.notation_sections set mode = 'chords', label = 'Intro riff'
where id = '20000000-0000-0000-0000-000000000001';

select pg_temp.check(
  (select mode from public.notation_sections where id = '20000000-0000-0000-0000-000000000001') = 'chords',
  'owner can toggle a notation section mode'
);

select pg_temp.check_fails(
  $$update public.notation_sections set musicxml = '<x/>'
    where id = '20000000-0000-0000-0000-000000000001'$$,
  'owner cannot write musicxml directly'
);

select pg_temp.check(
  (select status from public.jobs where id = '30000000-0000-0000-0000-000000000001') = 'running',
  'owner can read job progress'
);

-- Bob sees and changes nothing of Alice's ---------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');

select pg_temp.check((select count(*) from public.songs) = 0, 'other user sees no songs');
select pg_temp.check((select count(*) from public.recordings) = 0, 'other user sees no recordings');
select pg_temp.check((select count(*) from public.notation_sections) = 0, 'other user sees no notation sections');
select pg_temp.check((select count(*) from public.jobs) = 0, 'other user sees no jobs');
select pg_temp.check((select count(*) from public.pdfs) = 0, 'other user sees no pdfs');
select pg_temp.check(
  (select count(*) from storage.objects where bucket_id in ('recordings', 'pdfs')) = 0,
  'other user sees no storage objects'
);

update public.songs set title = 'Hijacked' where id = '10000000-0000-0000-0000-000000000001';
delete from public.songs where id = '10000000-0000-0000-0000-000000000001';
update public.notation_sections set mode = 'notation' where id = '20000000-0000-0000-0000-000000000001';

select pg_temp.check_fails(
  $$insert into public.recordings (song_id, audio_path)
    values ('10000000-0000-0000-0000-000000000001', 'x')$$,
  'other user cannot attach a recording to the song'
);

select pg_temp.check_fails(
  $$insert into public.jobs (song_id, type)
    values ('10000000-0000-0000-0000-000000000001', 'render_pdf')$$,
  'other user cannot queue a job on the song'
);

-- Anonymous visitors see nothing --------------------------------------------------

select pg_temp.act_as_anon();

select pg_temp.check_fails('select * from public.songs', 'anon cannot read songs');
select pg_temp.check_fails('select * from public.jobs', 'anon cannot read jobs');
select pg_temp.check(
  (select count(*) from storage.objects where bucket_id in ('recordings', 'pdfs')) = 0,
  'anon sees no storage objects'
);

-- Alice's data survived Bob ---------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');

select pg_temp.check(
  (select title from public.songs where id = '10000000-0000-0000-0000-000000000001') = 'Morning Light',
  'other user''s update and delete had no effect'
);
select pg_temp.check(
  (select mode from public.notation_sections where id = '20000000-0000-0000-0000-000000000001') = 'chords',
  'other user''s notation update had no effect'
);

select pg_temp.check_fails(
  $$update public.songs set user_id = '00000000-0000-0000-0000-00000000000b'
    where id = '10000000-0000-0000-0000-000000000001'$$,
  'owner cannot hand a song to another user'
);

-- Constraints -------------------------------------------------------------------------

select pg_temp.check_fails(
  $$insert into public.songs (title, instrument, capo) values ('P', 'piano', 1)$$,
  'capo is guitar only'
);
select pg_temp.check_fails(
  $$insert into public.songs (title, instrument) values ('V', 'violin')$$,
  'instrument must be guitar or piano'
);
select pg_temp.check_fails(
  $$update public.songs set listen_token = 'short' where id = '10000000-0000-0000-0000-000000000001'$$,
  'listen_token must be 22 URL-safe characters'
);

update public.songs set listen_token = 'abcdefghijklmnopqrstu_'
where id = '10000000-0000-0000-0000-000000000001';
select pg_temp.check(
  (select listen_token from public.songs where id = '10000000-0000-0000-0000-000000000001')
    = 'abcdefghijklmnopqrstu_',
  'a valid listen_token is accepted'
);

-- Deleting a song cascades ------------------------------------------------------------

delete from public.songs where id = '10000000-0000-0000-0000-000000000001';

select pg_temp.act_as_service();
select pg_temp.check(
  not exists (select 1 from public.recordings where song_id = '10000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.jobs where song_id = '10000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.notation_sections where song_id = '10000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.pdfs where song_id = '10000000-0000-0000-0000-000000000001'),
  'deleting a song removes its recordings, jobs, notation sections and pdfs'
);

rollback;
