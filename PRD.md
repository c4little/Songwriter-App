# Songwriter Transcription App: V1 Prototype PRD

Oct 3, 2026 · @Caleb Little

**Status:** Draft v3, build spec | **Scope:** V1 | **Owner:** Caleb

## 0. How to use this document (for Claude Code)

This is the source of truth for building V1. Save it in the repo as `docs/PRD.md` and reference it from `CLAUDE.md`.

- **Build phase by phase** in the order in section 15. Do not start a phase until the previous phase meets its acceptance criteria in section 16.
- **Stop at the decision gate** (phase 2). Report the evaluation results to Caleb and wait for a go/no-go before writing any UI.
- **Use only the stack in section 7.** Do not add services, databases, queues or paid APIs without asking.
- **Treat sections 9 to 13 as contracts.** If something in them is wrong or unworkable, stop and propose a change rather than working around it silently.
- **Do not build anything listed as a non-goal** in section 2.
- **At the end of each phase**, summarize what was built, what was tested, and any deviations from this document.

## 1. Product summary

A responsive web app for songwriters. The user records a song (voice plus guitar or piano) and gets back an editable lead sheet: lyrics with chords above the right words, plus key, tempo and time signature. Instrumental and fingerpicked passages are shown as guitar tab or piano notation. The user corrects it, saves it, and gets a PDF in their library and inbox, with a QR code that plays back the original recording.

**Problem:** capturing a song idea takes several manual steps (record a demo, write lyrics, work out chords, store it all) and leaves ideas scattered across voice memos, notebooks and notes apps.

**Target users:** solo, beginner-to-intermediate songwriters who play **guitar or piano** and sing. Guitar and piano are equal, first-class instruments throughout the product, the pipeline and the test set.

**Differentiation:** existing tools (for example Chordify and Moises) cover pieces of this. We own the complete loop: record, get an edited lead sheet with tab or notation where it matters, keep it in an organized library, and hand someone a printed sheet whose QR code plays the demo.

## 2. Scope

**Goals (V1)**

- Recording to readable lead sheet PDF with no manual transcription, for guitar and for piano.
- Chords of any type (triads, 7ths, extended, altered, slash chords) placed above the correct words.
- Guitar tab or piano notation for instrumental and fingerpicked sections.
- Click-to-place chord editing, plus a text mode for power users.
- Songs stay editable after saving; PDFs can be regenerated.
- PDF in a private library and by email, with a QR code that plays the original recording.
- Measure accuracy early and decide whether it is good enough before building UI.

**Non-goals (V1)**

- Full engraved scores of the whole song (melody notation on vocal sections).
- Editing individual notes inside tab or notation sections (users can toggle, regenerate or hide a section).
- Instruments other than guitar and piano; multi-instrument or full-band recordings.
- Collaboration, social features or a public library (the QR listen link is the only sharing).
- Native mobile apps; V1 is a responsive web app.
- Payments, subscriptions and pricing.

## 3. User flow

1. User signs in with an emailed magic link.
2. User picks the instrument (**Guitar** or **Piano**; defaults to their last choice), then taps **Record** and performs. The screen stays awake, and the take is kept in the browser until the upload is confirmed. Alternatively, the user uploads an audio file.
3. The app uploads the audio and shows processing progress by stage.
4. The app returns a lead sheet: chords above lyrics, section labels, key, tempo, time signature (default 4/4), and tab or notation blocks for instrumental and fingerpicked sections.
5. User sets a title (and a capo position for guitar), then corrects chords by clicking words, edits lyrics, renames or relabels sections, and toggles any section between chords and tab/notation.
6. User taps **Save**. The app stores the song, renders the PDF with a QR code, adds it to the library and emails it.
7. Later, the user can reopen the song, edit it and regenerate the PDF, turn the listen link off or regenerate it, or delete the song.
8. Anyone who scans the QR on the PDF lands on a simple listen page that plays the original recording.

## 4. Functional requirements

All are V1 must-haves unless marked otherwise. IDs (FR-n) are referenced by the build plan.

| ID | Requirement |
| --- | --- |
| FR-1 | Magic-link email sign-in; private per-user song library (Supabase row-level security on every table) |
| FR-2 | Instrument selection per song: guitar or piano; drives separation stem, capo visibility and tab vs notation rendering |
| FR-3 | In-browser recording up to 5 minutes with start, stop and playback; Wake Lock keeps the screen on |
| FR-4 | Take kept locally (IndexedDB) until upload succeeds; retry on failure |
| FR-5 | Upload of an existing audio file (mp3, m4a, wav, webm); server normalizes all audio with ffmpeg |
| FR-6 | Source separation into a vocal stem and an instrument stem |
| FR-7 | Lyric transcription with line breaks and word-level timestamps |
| FR-8 | Chord recognition with timestamps across the full chord vocabulary in section 5 |
| FR-9 | Key and tempo detection; time signature defaults to 4/4 with a picker |
| FR-10 | Alignment that places each chord change above the correct word |
| FR-11 | Section detection: vocal sections vs instrumental sections, and fingerpicked passages (rules in section 5) |
| FR-12 | Note transcription for instrumental and fingerpicked sections, rendered as guitar tab (with standard notation above) or piano grand-staff notation |
| FR-13 | Song stored as ChordPro plus metadata, with notation sections referenced from it (section 9) |
| FR-14 | Click-to-place chord editor with chord picker; text mode for raw ChordPro; both edit the same document (section 12) |
| FR-15 | Per-section toggle between chords and tab/notation; regenerate a section's tab/notation |
| FR-16 | Title field; capo field for guitar that changes displayed chord shapes |
| FR-17 | Section labels (Verse, Chorus, Bridge, Intro, Solo, Outro) in editor and PDF |
| FR-18 | PDF rendered from the same lead sheet component as the preview, including tab/notation and a QR code (section 13) |
| FR-19 | QR listen link: public page that plays the original recording; owner can disable or regenerate it |
| FR-20 | PDF saved to the library and emailed (attachment plus link to the song) |
| FR-21 | Reopen, edit and regenerate the PDF for any saved song |
| FR-22 | Library: title, instrument, date, play audio, download PDF, download ChordPro, delete |
| FR-23 | Processing status by stage and specific error messages |

**Nice to have (post-V1):** chord diagrams for guitar and piano; transpose; note-level editing in tab/notation; melody notation for vocal sections; MusicXML export.

## 5. Musical scope

### Instruments

|  | Guitar | Piano |
| --- | --- | --- |
| Separation stem | Guitar stem | Piano stem |
| Capo field | Yes; shows chord shapes relative to the capo | Hidden |
| Instrumental and fingerpicked sections | Tab (6 strings, standard tuning) with standard notation above | Grand staff notation, both hands (treble and bass clef) |
| Test set share | 50% | 50% |

Piano has no standard tab format, so piano "tab" means simplified grand-staff notation. Alternate guitar tunings are out of scope for V1.

### Chord vocabulary

Every layer (recognition, data model, editor, picker, renderer, capo shift) supports the full grammar below. Implement one parser and normalizer in TypeScript and one in Python, both tested against a shared fixture file (`shared/chord_fixtures.json`) so they agree.

| Part | Allowed values | Examples |
| --- | --- | --- |
| Root | A to G, with # or b | C, F#, Bb |
| Quality | major (none), m, dim, aug, sus2, sus4, 5 | Am, Bdim, Dsus4, E5 |
| Sevenths and sixths | 6, 7, maj7, m7, m(maj7), m7b5, dim7 | G7, Cmaj7, Bm7b5 |
| Extensions | 9, 11, 13 (and maj9, m9, m11, maj13 etc.), add9, add11, 6/9 | Cmaj9, Dm11, Fadd9, G6/9 |
| Alterations | b5, #5, b9, #9, #11, b13 | E7#9, G7b9, Cmaj7#11 |
| Slash bass | /note | C/G, D/F# |

Display spelling: sharps or flats follow the detected key; output in a consistent canonical form (for example `Cmaj7`, not `CM7` or `CΔ7`).

### Section rules

- **Vocal section:** lyrics present; rendered as chords over lyrics.
- **Instrumental section:** vocal-stem energy below a threshold for at least 2 bars (intro, solo, interlude, outro). Default render: tab (guitar) or notation (piano), plus the chord names above.
- **Fingerpicked passage:** in the instrument stem, more than 60% of note onsets have 2 or fewer simultaneous notes (arpeggiated rather than strummed or block chords). Default render: tab or notation, even under lyrics; lyrics stay aligned beneath.
- Thresholds live in one config file and are tuned in phase 1. The user can override any section in the editor (FR-15).

## 6. Architecture

The browser records and edits; Supabase stores everything; Modal does all audio processing and PDF rendering; Resend sends email.

&#91;embedded content: V1 processing pipeline · 10 steps\]

The alignment step decides whether the lead sheet is readable, so chord placement is measured on its own in phase 1. Section 11 specifies each step's input and output.

## 7. Tech stack

Four services: Vercel, Supabase, Modal, Resend. Items marked **(eval)** are compared in phase 1; the winner is locked at the decision gate.

| Layer | Choice | Notes |
| --- | --- | --- |
| Frontend | Next.js (App Router), TypeScript strict, Tailwind, on Vercel | MediaRecorder, Wake Lock and IndexedDB browser APIs |
| Auth, database, storage | Supabase | Magic link, Postgres with row-level security, private storage buckets |
| Job queue | `jobs` table; frontend subscribes with Supabase Realtime (polling fallback every 3 s) | No Redis or Celery |
| Processing | Python 3.11 functions on Modal (GPU) | `process_song`, `regenerate_section`, `render_pdf` |
| Audio prep | ffmpeg | Convert to 44.1 kHz mono WAV |
| Source separation | Demucs, 6-stem model (guitar and piano stems) **(eval)** vs 4-stem model's "other" stem | Piano stem quality is the main question |
| Lyrics | WhisperX on the vocal stem | Word-level timestamps |
| Chords | Large-vocabulary deep-learning recognizer (e.g. BTC) **(eval)** vs Chordino | Must cover section 5 vocabulary; Chordino's vocabulary is narrower |
| Key and tempo | librosa | Beat grid also used for bar lines in notation |
| Note transcription | Basic Pitch (polyphonic, outputs note events) **(eval)** vs a piano-specific transcription model for piano | Only run on instrumental and fingerpicked sections |
| Score building | music21 | Quantize notes to the beat grid; write MusicXML per section |
| Guitar fingering | Custom Python: assign string and fret by minimizing hand movement, capo-aware | Standard tuning only |
| Notation rendering | alphaTab (browser) | Renders tab, standard notation and grand staff from MusicXML |
| QR code | `qrcode` npm package | Rendered as SVG in the lead sheet header |
| PDF | Playwright (headless Chromium) on Modal prints the app's `/print` route | Same component as the preview, so alphaTab output matches |
| Email | Resend | PDF attachment plus link |
| Tests | Vitest (web), pytest (worker), Playwright (end-to-end) |  |

## 8. Repository layout

One monorepo. Keep this structure unless a change is agreed.

```
/apps/web                  Next.js app
  app/login                magic-link sign-in
  app/library              song list
  app/record               instrument picker, recorder, upload
  app/songs/[id]/edit      lead sheet editor
  app/songs/[id]/print     print-only route used to render the PDF
  app/listen/[token]       public listen page (QR target)
  app/api/...              route handlers (section 10)
  lib/chords               chord parser, normalizer, capo shift
  lib/chordpro             ChordPro parser and serializer
  components/editor        click-to-place editor, chord picker, text mode
  components/leadsheet     lead sheet renderer (preview and print)
  components/notation      alphaTab wrapper
/worker                    Python on Modal
  app.py                   Modal functions and web endpoints
  pipeline/                normalize, separate, lyrics, chords, keytempo,
                           sections, notes, align, fingering, score, chordpro
  render/                  render_pdf (Playwright), email (Resend)
  eval/                    run_eval.py, metrics.py, report.md output
  config.py                thresholds and model choices
/shared
  chord_fixtures.json      chord strings and expected parses (used by both test suites)
/supabase
  migrations/              SQL schema and RLS policies
/testdata                  labels committed; audio gitignored
/docs/PRD.md               this document
```

## 9. Data model

### Tables

Every table has row-level security limiting rows to the owning user. Only the service role (worker and listen page server code) bypasses it.

| Table | Columns |
| --- | --- |
| songs | id (uuid), user\_id, title, instrument ('guitar' or 'piano'), chordpro\_text, key, tempo\_bpm, time\_signature (default '4/4'), capo (int, guitar only), listen\_token (text, unique, nullable), listen\_enabled (bool, default true), word\_timings (jsonb: line and word positions with start times from processing; used for audio sync, best effort after lyric edits), created\_at, updated\_at |
| recordings | id, song\_id, audio\_path, normalized\_path, vocal\_stem\_path, instrument\_stem\_path, duration\_s |
| notation\_sections | id, song\_id, label, start\_s, end\_s, kind ('instrumental' or 'fingerpicked'), mode ('notation' or 'chords'), musicxml (text), source ('auto' or 'user'), updated\_at |
| jobs | id, song\_id, type ('process', 'regenerate\_section', 'render\_pdf'), status ('queued', 'running', 'done', 'failed'), stage (text), progress (0 to 100), error\_code, error\_message, cost\_usd, created\_at, finished\_at |
| pdfs | id, song\_id, pdf\_path, generated\_at |

Storage buckets (private): `recordings/{user_id}/{song_id}/...` and `pdfs/{user_id}/{song_id}/{pdf_id}.pdf`.

### ChordPro conventions

`songs.chordpro_text` is the single source of truth for lyrics, chords and section order. Notation sections are referenced with a custom directive (ChordPro allows `x_` prefixes):

```
{title: Morning Light}
{key: G}
{tempo: 92}
{time: 4/4}
{capo: 2}

{start_of_part: Intro}
{x_notation: 7c1e...}
[G] [Cmaj7] [D/F#] [Em9]
{end_of_part}

{start_of_verse}
[G]Hold me [Cmaj7]close when the [D/F#]morning [Em9]comes
{end_of_verse}

{start_of_chorus}
[C]Stay [G/B]here, [Am7]stay [D7sus4]here
{end_of_chorus}
```

- `{x_notation: <notation_section_id>}` inside a section means "render this section's notation"; the chord line stays as the chord names shown above it.
- When a section's mode is 'chords', the renderer ignores the directive.
- Chords inside brackets must parse with the section 5 grammar; the editor rejects invalid chords.
- Recordings are kept until the user deletes the song and are never used for model training.

## 10. API and job contracts

The browser uploads audio directly to Supabase Storage, then calls Next.js route handlers. Route handlers call Modal web endpoints with a shared secret header (`X-Worker-Secret`). Modal writes results and job status straight to Supabase with the service role.

| Endpoint | Caller | Does |
| --- | --- | --- |
| `POST /api/songs` | Browser, after upload | Body: `{instrument, audio_path, title?}`. Creates song, recording and a 'process' job; triggers Modal `process_song(job_id)`. Returns `{song_id, job_id}`. |
| `PATCH /api/songs/:id` | Editor | Saves `chordpro_text`, title, key, tempo, time signature, capo, section modes. Validates ChordPro and chords. |
| `POST /api/songs/:id/sections/:sid/regenerate` | Editor | Creates a 'regenerate\_section' job; Modal re-runs notes, fingering and score for that time range. |
| `POST /api/songs/:id/render` | Editor (Save) | Ensures a listen token exists; creates a 'render\_pdf' job; Modal `render_pdf` prints `/songs/:id/print`, stores the PDF and emails it. |
| `POST /api/songs/:id/listen-link` | Library or editor | Body: `{action: 'disable' or 'enable' or 'regenerate'}`. Regenerating invalidates existing printed QR codes; the UI warns first. |
| `DELETE /api/songs/:id` | Library | Deletes rows and all storage objects for the song. |
| `GET /listen/:token` | Anyone | Public page; server code looks up the token with the service role and returns a signed audio URL valid for 1 hour, created on each page load. 404 if disabled or unknown. |
| `GET /songs/:id/print` | Modal Playwright only | Print layout; authorized by a short-lived signed render token in the query string. |

**Job lifecycle:** queued → running (stage updates: normalizing, separating, transcribing lyrics, detecting chords, detecting sections, transcribing notes, aligning, building song) → done or failed. On failure, set `error_code` (for example `NO_VOCALS_DETECTED`, `CHORDS_UNCERTAIN`, `AUDIO_TOO_LONG`, `PROCESSING_ERROR`) and a user-readable `error_message`. Record `cost_usd` per job from Modal billing.

## 11. Processing pipeline

`process_song` runs these steps in order. Each step is a pure function in `worker/pipeline/` with unit tests, so phase 1 can run them offline on the test set.

| # | Step | Input | Output | Tool |
| --- | --- | --- | --- | --- |
| 1 | normalize | Uploaded audio | 44.1 kHz mono WAV; reject if over 5 min | ffmpeg |
| 2 | separate | WAV, instrument | Vocal stem, instrument stem | Demucs |
| 3 | lyrics | Vocal stem | Lines of words, each word with start and end time | WhisperX |
| 4 | keytempo | Instrument stem | Key, tempo, beat and bar grid | librosa |
| 5 | chords | Instrument stem | List of (start, end, chord label) using section 5 vocabulary | Chord recognizer |
| 6 | sections | Vocal stem, instrument stem, lyrics | Time ranges labeled vocal, instrumental or fingerpicked | Rules in section 5 |
| 7 | notes | Instrument stem, instrumental and fingerpicked ranges | Note events (pitch, onset, duration, velocity) | Basic Pitch or piano model |
| 8 | fingering | Notes, capo (guitar only) | String and fret per note | Custom |
| 9 | score | Notes (+ fingering), beat grid, key, time signature | MusicXML per notation section | music21 |
| 10 | align | Lyrics, chords, sections, bar grid | Chord-over-word placement; chord-only lines for instrumental sections | Custom |
| 11 | chordpro | All of the above | ChordPro text with section blocks and `x_notation` directives; rows in `notation_sections` | Custom |

**Alignment rules (step 10):** each chord change attaches to the word whose start time is nearest, within half a beat; a change that falls in a gap between words attaches to the next word with a leading space; changes during an instrumental section go on a chord-only line, one bar per chord slot. Repeated identical chords on consecutive words collapse into one.

**Performance target:** under 2 minutes end to end for a 3-minute song, including notation for up to 60 seconds of instrumental or fingerpicked audio.

## 12. Frontend

Mobile-first and responsive; every screen must work on a phone held on a music stand.

| Screen | Contents |
| --- | --- |
| Login | Email field, magic-link confirmation state |
| Library | Song cards: title, instrument icon, date, play, PDF, ChordPro download, delete (with confirm); "New song" button |
| Record | Guitar or Piano toggle; big record button with timer and 5:00 limit; playback; "Use this take" or "Record again"; upload-a-file link; tip to record in a quiet room |
| Processing | Stage-by-stage progress from the job row; error state with the message and a "Try again" action |
| Editor | Header fields (title, key, tempo, time signature, capo for guitar), the lead sheet in click-to-place mode, a "Text" tab for raw ChordPro, audio player synced to the sheet, Save |
| Listen | Song title, instrument, audio player; no other song data; works without sign-in |

### Click-to-place chord editor

The editor renders the lead sheet from ChordPro and writes every change back to ChordPro, so the text tab always matches.

- **Place:** click or tap any word, or the gap before it, to open the chord picker anchored there. The new chord is inserted at that position.
- **Edit:** click an existing chord chip to reopen the picker with that chord loaded; the picker has a delete button.
- **Move:** drag a chord chip to another word (desktop); on touch, long-press the chip, then tap the destination word.
- **Chord picker:** a typed input with autocomplete (type `Cmaj9` and press Enter) plus tap-to-build controls: root, quality, seventh, extensions, alterations, slash bass. Shows recently used chords from this song as one-tap chips. Rejects anything outside the section 5 grammar.
- **Lyrics:** edit text inline; chords stay attached to their word when nearby text changes.
- **Sections:** each section has a label menu (rename, Verse, Chorus, Bridge, Intro, Solo, Outro), and for notation-capable sections a toggle "Chords / Tab" (guitar) or "Chords / Notation" (piano) plus "Regenerate".
- **Audio sync:** clicking a word seeks the player to that word's timestamp; the current line highlights during playback.
- **Undo and redo** for every change; unsaved-changes warning on leave.
- **Capo:** changing the capo re-renders chord names as shapes relative to the capo; stored chords remain concert pitch.

## 13. PDF and QR code

The PDF is Playwright's print of `/songs/:id/print`, which uses the same lead sheet and alphaTab components as the editor preview. US Letter for all users; no page-size setting in V1.

**Page 1 header:** title (large), then a line with key, tempo, time signature, instrument and capo (guitar only). The QR code sits at the top right, about 2.5 cm square, with the caption "Scan to hear the demo".

**Body:** sections in ChordPro order, each with its label in bold. Chord names sit above the exact syllable in a monospace-aligned or absolutely positioned layout. Notation sections render with alphaTab: guitar shows standard notation above tab; piano shows a grand staff with both hands. Chord names stay above notation sections.

**Pagination:** never split a section's chord line from its lyric line; avoid splitting a notation system across pages. Page numbers and the song title appear in the footer from page 2.

**QR code:**

- Encodes `https://<APP_BASE_URL>/listen/<listen_token>`; the token is 22 random URL-safe characters.
- A token is created on the first render and reused on later renders, so old printouts keep working.
- If the owner disables the link, the QR shows a "This recording isn't available" page. If they regenerate it, old QR codes stop working (the UI warns first).
- The listen page never requires sign-in: anyone holding the QR code is assumed to have the artist's permission. The editor shows a one-line notice explaining this next to the toggle.
- Error correction level M; dark modules on white, with a quiet zone of 4 modules.

**Email (Resend):** subject "Your lead sheet: \<title>"; body with a link to the song in the app; PDF attached (if it exceeds 10 MB, send only the link).

## 14. Configuration and conventions

**Environment variables** (document all of them in `.env.example`; never commit secrets):

| Variable | Used by |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Web |
| `SUPABASE_SERVICE_ROLE_KEY` | Web server code (listen page, delete), worker |
| `MODAL_ENDPOINT_URL`, `WORKER_SECRET` | Web route handlers, worker |
| `RENDER_TOKEN_SECRET` | Signs short-lived tokens for the print route |
| `RESEND_API_KEY`, `EMAIL_FROM` | Worker |
| `APP_BASE_URL` | QR links, email links, print route |

**Conventions**

- TypeScript strict mode; no `any` in `lib/`. Python with type hints; `ruff` for lint and format.
- Every pipeline step and every `lib/` module has unit tests. The chord parsers in both languages pass `shared/chord_fixtures.json`.
- All thresholds and model names live in `worker/config.py`, not inline.
- Database changes only through migrations in `/supabase/migrations`, each with RLS policies.
- Log one structured line per pipeline step (job\_id, step, duration\_s, outcome) to make cost and speed tracking easy.
- Keep dependencies minimal; ask before adding a library not named in this document.

## 15. Build plan

Build in this order. Each phase ends when it meets its criteria in section 16; report results to Caleb before moving on.

0. **Setup and competitor review:** scaffold the monorepo (section 8), Supabase project and migrations with RLS, Modal app skeleton, CI running tests. Caleb tries the leading chord and lyric tools on a few test songs to confirm the differentiation in section 1.
1. **Analysis prototype:** implement pipeline steps 1 to 11 (section 11) as offline functions and the chord parsers. Run the 30-recording test set (section 17), compare every (eval) option in section 7, tune section-detection thresholds, and write \`worker/eval/report.md\` with all metrics.
2. **Decision gate:** if chord accuracy is below 60% (exact match, all chord types) for either instrument, or note accuracy in notation sections is below 50%, stop and agree a narrower scope with Caleb before building any UI. Otherwise lock the model choices in \`worker/config.py\`.
3. **Backend pipeline:** Modal functions and web endpoints, \`jobs\` lifecycle, Next.js route handlers in section 10, storage paths, error codes, cost logging.
4. **Frontend:** login, library, record (both instruments), processing screen, and the editor with click-to-place chords, chord picker, text mode, section toggles, audio sync, undo and capo (section 12).
5. **Notation, PDF, QR and email:** alphaTab wrapper for tab and grand staff, section regeneration, print route, Playwright rendering, QR code and listen page, Resend delivery, reopen and regenerate (section 13).
6. **Testing:** end-to-end Playwright tests for the full flow on both instruments, then a trial with at least 5 guitarists and 5 pianists, reviewed against section 17.

## 16. Phase acceptance criteria

| Phase | Done when | FRs covered |
| --- | --- | --- |
| 0. Setup | Repo matches section 8; migrations apply cleanly with RLS on every table; Modal hello-world endpoint is callable with the secret; CI runs Vitest and pytest green | FR-1 (schema) |
| 1. Analysis prototype | All 11 steps run offline on all 30 recordings; both chord parsers pass the shared fixtures; `report.md` lists every section 17 metric per instrument and per (eval) option, plus processing time and cost per song | FR-6 to FR-13 |
| 2. Decision gate | Caleb has reviewed the report and given a written go, or an agreed narrower scope | — |
| 3. Backend | Uploading a test file via the API produces a song with ChordPro and notation rows; job stages update in order; each error code can be triggered by a test; cost is recorded | FR-5 to FR-13, FR-23 |
| 4. Frontend | On a phone and a desktop: sign in, record on both instruments, watch progress, place, edit, move and delete chords by click, switch to text mode and back without losing changes, toggle sections, undo, save | FR-1 to FR-4, FR-14 to FR-17, FR-21, FR-22 |
| 5. Notation, PDF, QR, email | Guitar tab and piano grand staff render in editor and PDF identically; PDF matches section 13; QR scanned from a printed page plays the recording on a phone that isn't signed in; disabling the link stops playback; email arrives with attachment | FR-12, FR-15, FR-18 to FR-20 |
| 6. Testing | End-to-end tests pass for both instruments; the user trial is complete and section 17 metrics are reported | All |

## 17. Evaluation and success metrics

**Test set: 30 hand-labeled recordings,** 15 guitar and 15 piano. At least 10 use extended or altered chords; at least 8 include an instrumental or fingerpicked section; mixed voices, tempos and recording conditions (mostly quiet rooms, a few noisy phone recordings). Labels per song: lyrics, timed chords, section boundaries and types, and notes for notation sections (MIDI or MusicXML). Store labels in `/testdata`.

All accuracy metrics are scored before user edits and reported separately for guitar and piano.

| Metric | Target | How it's measured |
| --- | --- | --- |
| Chord root accuracy | 85% or higher | Share of song time with the correct chord root |
| Chord exact accuracy | 65% or higher | Share of song time with the exact chord, all types |
| Extended-chord accuracy | Report; no V1 target | Exact accuracy on 9th, 11th, 13th and altered chords only |
| Chord placement | 70% or higher | Share of chords placed above the correct word |
| Lyric accuracy | 80% or higher | 1 minus word error rate |
| Section detection | 80% or higher | Share of instrumental and fingerpicked sections found within 1 bar of their boundaries |
| Note accuracy (notation sections) | 60% or higher | Note F-measure, onset within 50 ms and correct pitch |
| Processing time | Under 2 minutes | 3-minute song |
| Time to PDF | Under 4 minutes | End of recording to saved PDF, including edits |
| Edits per song | Track | Chord and lyric edits before Save |
| Completion rate | 60% or higher | Recordings that end in a saved PDF |
| User feedback | 8 of 10 trial users | Say they would use it again |

## 18. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Note transcription for tab and notation is unreliable, especially polyphonic piano | Only applied to instrumental and fingerpicked sections; per-section regenerate and toggle back to chords; note accuracy gate in phase 2 |
| Extended and altered chords are recognized far less accurately than triads | Large-vocabulary recognizer evaluated in phase 1; root accuracy tracked separately; picker makes fixes fast |
| Piano separation stem is weak | Compare 6-stem and 4-stem separation in phase 1; fall back to the unseparated mix for piano if it scores better |
| Chords land on the wrong words | Word timestamps plus explicit alignment rules; placement metric |
| Public listen links expose unreleased songs | Unguessable tokens; disable and regenerate controls; notice in the editor; audio served by short-lived signed URLs |
| Editor complexity (click-to-place, text mode and notation in one view) | ChordPro as the single model behind both modes; unit tests on round-tripping; undo stack |
| PDF and preview drift apart | One shared renderer; PDF printed from the app's own print route |
| Lost takes (upload failure, screen lock, browser formats) | IndexedDB copy until upload confirms; Wake Lock; ffmpeg normalization |
| GPU cost per song rises with notation | 5-minute cap; notes only on selected sections; cost recorded per job |
| Existing tools cover parts of this | Focus on the full record-to-printed-sheet loop; competitor check in phase 0 |

## 19. Decisions and open questions

| Question | Decision |
| --- | --- |
| Which instruments? | Guitar and piano, both first-class |
| Chord vocabulary? | All types: triads, 7ths, extended, altered, slash chords |
| Click-to-place editing? | In V1, alongside a text mode |
| Tab and notation? | In V1 for instrumental and fingerpicked sections: guitar tab, piano grand staff |
| Piano notation detail? | Both hands (treble and bass clef), never simplified to melody only |
| QR code to the recording? | In V1; public by unguessable link, owner can disable or regenerate |
| Sign-in to listen? | No. Anyone with the QR code can listen; we assume they have the artist's permission |
| Page size? | US Letter for all users; no page-size setting in V1 |
| Melody notation for vocal sections? | Not in V1 |
| Export formats? | PDF and ChordPro; MusicXML later |
| Recording retention? | Until the user deletes the song |
| Pricing? | Out of scope; track cost per job |
