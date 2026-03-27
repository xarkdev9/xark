# CLAUDE.md — hello Monorepo

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Structure
- engine/ — Flutter E2EE chat engine (package: hello_engine)
- app/    — Flutter app shell (package: hello_app, imports engine/)
- web/    — Next.js web app (React + API)
- algo/   — Decision engine (TypeScript, pure logic)
- docs/   — Architecture and audit docs

## Terminology
| Term | Meaning | Old name |
|------|---------|----------|
| group | Shared conversation space | space |
| dm | 1:1 direct message | sanctuary |
| home | Main screen | galaxy |
| hello | The AI assistant | xark, @xark |
| group_id | FK to groups table | space_id |
| invite | Join link | summon |
| suggestions | Proactive hints | whispers |
| consensus | Voting module | handshake |

## Commands
```bash
cd engine && flutter test             # E2EE engine tests (290+)
cd app    && flutter run -d chrome    # Flutter app
cd web    && npm run dev              # Next.js web app (port 3000)
cd algo   && npm test                 # Decision engine tests (198)
```

## Key Constraints
- E2EE is non-negotiable. No plaintext fallback. Ever.
- engine/ is headless — zero UI code. UI lives in app/.
- User IDs are text format (e.g., name_ram), not UUIDs.
- RLS uses auth.jwt()->>'sub' (not auth.uid()).
- Port 3000 only for web dev server.
