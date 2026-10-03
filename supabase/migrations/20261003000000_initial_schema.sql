-- Initial schema (PRD section 9). Every table has row-level security limiting
-- rows to the owning user. Only the service role (worker, listen page server
-- code) bypasses it.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- songs
-- ---------------------------------------------------------------------------

create table public.songs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null default '',
  instrument text not null check (instrument in ('guitar', 'piano')),
  chordpro_text text not null default '',
  key text,
  tempo_bpm numeric(6, 2) check (tempo_bpm is null or tempo_bpm > 0),
  time_signature text not null default '4/4' check (time_signature ~ '^[0-9]{1,2}/[0-9]{1,2}$'),
  capo int check (capo is null or capo between 0 and 12),
  listen_token text unique check (listen_token is null or listen_token ~ '^[A-Za-z0-9_-]{22}$'),
  listen_enabled boolean not null default true,
  word_timings jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Capo is guitar only (FR-16).
  constraint songs_capo_guitar_only check (capo is null or instrument = 'guitar')
);

create index songs_user_id_created_at_idx on public.songs (user_id, created_at desc);

create trigger songs_set_updated_at
before update on public.songs
for each row execute function public.set_updated_at();

-- Ownership check used by child-table policies. SECURITY DEFINER avoids
-- re-evaluating songs RLS inside every child policy; it only ever answers
-- for the calling user.
create or replace function public.owns_song(p_song_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.songs s
    where s.id = p_song_id and s.user_id = (select auth.uid())
  );
$$;

revoke all on function public.owns_song(uuid) from public;
grant execute on function public.owns_song(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- recordings
-- ---------------------------------------------------------------------------

create table public.recordings (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs (id) on delete cascade,
  audio_path text not null,
  normalized_path text,
  vocal_stem_path text,
  instrument_stem_path text,
  duration_s numeric(8, 3) check (duration_s is null or duration_s >= 0)
);

create index recordings_song_id_idx on public.recordings (song_id);

-- ---------------------------------------------------------------------------
-- notation_sections
-- ---------------------------------------------------------------------------

create table public.notation_sections (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs (id) on delete cascade,
  label text not null default '',
  start_s numeric(8, 3) not null check (start_s >= 0),
  end_s numeric(8, 3) not null,
  kind text not null check (kind in ('instrumental', 'fingerpicked')),
  mode text not null default 'notation' check (mode in ('notation', 'chords')),
  musicxml text,
  source text not null default 'auto' check (source in ('auto', 'user')),
  updated_at timestamptz not null default now(),
  constraint notation_sections_time_range check (end_s > start_s)
);

create index notation_sections_song_id_idx on public.notation_sections (song_id);

create trigger notation_sections_set_updated_at
before update on public.notation_sections
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- jobs
-- ---------------------------------------------------------------------------

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs (id) on delete cascade,
  type text not null check (type in ('process', 'regenerate_section', 'render_pdf')),
  status text not null default 'queued' check (status in ('queued', 'running', 'done', 'failed')),
  stage text,
  progress int not null default 0 check (progress between 0 and 100),
  error_code text,
  error_message text,
  cost_usd numeric(10, 4) check (cost_usd is null or cost_usd >= 0),
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create index jobs_song_id_created_at_idx on public.jobs (song_id, created_at desc);

-- ---------------------------------------------------------------------------
-- pdfs
-- ---------------------------------------------------------------------------

create table public.pdfs (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs (id) on delete cascade,
  pdf_path text not null,
  generated_at timestamptz not null default now()
);

create index pdfs_song_id_generated_at_idx on public.pdfs (song_id, generated_at desc);

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
-- anon gets nothing: the listen page reads through server code with the
-- service role. Columns written only by the worker (job status, stems, PDFs)
-- have no user write policy, so users cannot forge them.

alter table public.songs enable row level security;
alter table public.recordings enable row level security;
alter table public.notation_sections enable row level security;
alter table public.jobs enable row level security;
alter table public.pdfs enable row level security;

revoke all on public.songs, public.recordings, public.notation_sections, public.jobs, public.pdfs
  from anon;

-- songs: full CRUD on own rows.
create policy songs_select_own on public.songs
  for select to authenticated using (user_id = (select auth.uid()));
create policy songs_insert_own on public.songs
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy songs_update_own on public.songs
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy songs_delete_own on public.songs
  for delete to authenticated using (user_id = (select auth.uid()));

-- recordings: created by POST /api/songs as the user; stems written by the worker.
create policy recordings_select_own on public.recordings
  for select to authenticated using (public.owns_song(song_id));
create policy recordings_insert_own on public.recordings
  for insert to authenticated with check (public.owns_song(song_id));
create policy recordings_delete_own on public.recordings
  for delete to authenticated using (public.owns_song(song_id));

-- notation_sections: created by the worker; the editor changes label and mode.
create policy notation_sections_select_own on public.notation_sections
  for select to authenticated using (public.owns_song(song_id));
create policy notation_sections_update_own on public.notation_sections
  for update to authenticated
  using (public.owns_song(song_id))
  with check (public.owns_song(song_id));
create policy notation_sections_delete_own on public.notation_sections
  for delete to authenticated using (public.owns_song(song_id));

-- jobs: users queue jobs and watch them; only the worker moves them along.
create policy jobs_select_own on public.jobs
  for select to authenticated using (public.owns_song(song_id));
create policy jobs_insert_own on public.jobs
  for insert to authenticated
  with check (
    public.owns_song(song_id)
    and status = 'queued'
    and progress = 0
    and stage is null
    and error_code is null
    and error_message is null
    and cost_usd is null
    and finished_at is null
  );

-- pdfs: written by the worker; users list and delete their own.
create policy pdfs_select_own on public.pdfs
  for select to authenticated using (public.owns_song(song_id));
create policy pdfs_delete_own on public.pdfs
  for delete to authenticated using (public.owns_song(song_id));

-- Only the editable notation_sections columns may be updated by users.
revoke update on public.notation_sections from authenticated;
grant update (label, mode) on public.notation_sections to authenticated;

-- Realtime: the processing screen subscribes to its job row (PRD section 7).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.jobs;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage (private buckets)
-- ---------------------------------------------------------------------------
-- recordings/{user_id}/{song_id}/...   pdfs/{user_id}/{song_id}/{pdf_id}.pdf

insert into storage.buckets (id, name, public)
values ('recordings', 'recordings', false), ('pdfs', 'pdfs', false)
on conflict (id) do update set public = false;

-- The browser uploads takes directly to its own folder.
create policy recordings_objects_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'recordings' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy recordings_objects_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'recordings' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy recordings_objects_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'recordings' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- PDFs are written by the worker; users read and delete their own.
create policy pdfs_objects_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'pdfs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy pdfs_objects_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'pdfs' and (storage.foldername(name))[1] = (select auth.uid())::text);
