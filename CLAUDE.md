# Songwriter Transcription App

The full product and build spec is in `docs/PRD.md`. Read it before doing any work:

@docs/PRD.md

## Working rules

- Follow the build plan in PRD section 15, one phase at a time.
- A phase is done only when it meets its acceptance criteria in PRD section 16.
- At the end of each phase, stop and summarize what you built, what you tested, and any deviations from the PRD. Wait for my go-ahead before starting the next phase.
- Stop at the phase 2 decision gate, share the evaluation report, and wait for a go/no-go before writing any UI.
- Use only the tech stack in PRD section 7. Ask before adding any service, database, queue, paid API or library not named there.
- Treat PRD sections 9 to 13 as contracts. If something there is wrong or unworkable, propose a change instead of working around it.
- Never build anything listed as a non-goal in PRD section 2.
- Never commit secrets. Keep `.env.example` up to date with every variable in PRD section 14.

## Current status

Phase 0 (setup) has not started.
