# CLAUDE.md — xpensly/

Expense-splitting SDK for the hello monorepo. Three-layer architecture: pure Dart engine, Flutter widgets, and a REST API surface hosted in the web package.

## Layers

| Layer | Location | Language | Responsibility |
|-------|----------|----------|----------------|
| Core engine | `xpensly/xpensly_core/` | Pure Dart | Calculations, models, ports, adapters |
| UI widgets | `xpensly/xpensly_ui/` | Flutter | 9 composable themed widgets |
| REST API | `web/src/app/api/xpensly/` | TypeScript | 20 route handlers + 8 helper modules |

The REST API lives **outside** this directory — it is part of the Next.js web package, not a Dart package. Do not look for it here.

## Sub-docs

- `xpensly_core/CLAUDE.md` — engine internals, ports, adapters, test commands
- `xpensly_ui/CLAUDE.md` — widget inventory, theme system, test commands

## Test Commands

```bash
# Core engine (69 tests across 12 files)
cd xpensly/xpensly_core && dart test
cd xpensly/xpensly_core && dart analyze

# UI widgets (16 tests across 6 files)
cd xpensly/xpensly_ui && flutter test
```

## Dependency Graph

```
xpensly_ui  →  xpensly_core  (path: ../xpensly_core)
xpensly_core  →  collection: ^1.17.0  (only runtime dep)
web/api/xpensly  →  stateless calc + stateful trip REST handlers  (independent)
```

## Design Contract

- `xpensly_core` is Flutter-free. No `dart:ui`, no `package:flutter`. CI will catch violations.
- `xpensly_ui` depends on core via path dep — no pub.dev version during monorepo development.
- The REST API mirrors core logic for server-side calculation; it does not import Dart packages.

## Spec

`docs/superpowers/specs/2026-04-02-xpensly-sdk-design.md`

## Restoration History

`xpensly/xpensly_ui/` was empty as of 2026-04-11 morning. It was restored from:
```
ui_backup_2026-04-10/flutter/xpensly_ui/
```
If the directory goes empty again, that backup path is the recovery source. The backup contains `lib/` (with `src/widgets/`, `src/theme/`, `src/utils/` subtrees + the `xpensly_ui.dart` barrel), `test/widgets/` (6 test files), `pubspec.yaml`, `analysis_options.yaml`, and `example/`. There is no top-level `widgets/` directory — widget sources live under `lib/src/widgets/`.
