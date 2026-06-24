# Domain docs

This repo uses a **single-context** layout:

- One `CONTEXT.md` at the repo root — the project's domain language, core concepts, and vocabulary.
- `docs/adr/` at the repo root — Architecture Decision Records capturing past decisions and their trade-offs.

## Consumer rules

Skills that need domain understanding (`improve-codebase-architecture`, `diagnosing-bugs`, `tdd`, and similar) should:

1. Read `CONTEXT.md` at the repo root to learn the project's domain language before reasoning about the code.
2. Read `docs/adr/` for relevant prior architectural decisions before proposing or changing architecture.

There is a single global context — there is **no** `CONTEXT-MAP.md` and no per-package `CONTEXT.md` files. If Kiosk later grows into a monorepo with separate contexts (e.g. game engine vs. tooling), switch to a multi-context layout: add `CONTEXT-MAP.md` at the root pointing to per-context `CONTEXT.md` files, and update this doc.

## Setup status

> `CONTEXT.md` exists at the repo root (domain spine agreed 2026-06-24) and `docs/adr/` holds ADR-0001 (Godot 4.7 + GDScript). Keep `CONTEXT.md` current as open threads resolve, and add ADRs under `docs/adr/` as further architectural decisions are made. See also `docs/ROADMAP.md`.
