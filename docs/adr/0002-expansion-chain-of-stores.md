# ADR-0002: Expansion — the chain-of-stores model

- **Status:** Proposed
- **Date:** 2026-06-28
- **Deciders:** Asger (solo)

## Context

v1 and the whole roadmap "Next" phase are built and **proven fun** (F5 sign-off,
2026-06-28). The roadmap now moves to **Later**, and the first epic chosen is
**Expansion** — already a named pillar in `CONTEXT.md`: *"the number-go-up spine.
Staged growth: deepen a flagship kiosk → build a chain of locations → branch
vertically into supply/distribution and new store types. Stores can be maxed out,
and a maxed legit store becomes a front."*

Today the game is a **single store**. `GameState` holds one `money` wallet, one
`stock` dict, one `upgrades` dict, the review totals + `best_rating`, and the `day`.
`DayCycle` runs exactly one PROCURE→SERVE→UPGRADE loop per day over that single
store. Every phase scene implicitly operates on "the store" because there is only one.

Expansion forces the first structural question the codebase has been able to avoid:
**how does the single-store model and the day loop generalize to many stores without
breaking the design invariants** —
no-fail (1), one continuous economy (2), the day is the unit (3), automation is the
bridge (4), legit serves the illegal (5)?

Key forces:

- The chain must *feel* like the **payoff of the automation bridge already shipped**
  (the clerk), not a bolted-on second subsystem.
- The player can only be in one place. Running every store by hand each day doesn't
  scale and would break the idle promise.
- **Real saves exist (format v2).** A model change must migrate them, not orphan them.
- Keep the established architecture: pure `RefCounted`/static logic + thin scene,
  GameState-shaped dependency injection, headless unit tests (see `tests/`).

## Decision

Introduce a **`Store`** as a first-class entity and make the chain the spine of
expansion, with three pinned sub-decisions.

### 1. A `Store` owns per-location state; the chain shares one wallet

Extract the per-store fields — `stock`, `upgrades`, `review_points` / `review_count`,
`best_rating`, plus identity (`name` / town) — into a `Store` model. `GameState`
becomes: one global `money`, the `day`, an array `stores: Array[Store]`, and an
`active_store` index.

- **Money is never per-store; stock / upgrades / rating are always per-store.** A
  single shared wallet is what makes a chain feel like one empire and keeps invariant 2
  ("one continuous economy") *literally* true. Ratings and stock are inherently local
  to a location.
- This also fits the code's grain: `Procure` and `Shift` already take a
  "GameState-shaped" object (anything with `money` + `stock`). A `Store` paired with the
  shared wallet **can be that injected object**, so the pure logic barely changes.

### 2. You actively run one store per day; staffed stores run themselves (idle)

The day loop operates on the **active store** — the one you are "visiting" — exactly as
today. Every *other* store produces **automated output only if it is staffed** (a clerk
hired there); an unstaffed store you are not at simply does not trade that day.

This makes the chain the direct, literal embodiment of **invariant 4 (automation is the
bridge)**: a second location is only worth opening once you can staff it, so *expansion
is graduating more of the business to idle*. The **active option always remains** — you
may choose to visit any store and run its shift by hand.

### 3. Idle income generalizes the existing day / offline math over staffed stores

A staffed store's per-day automated output feeds the shared wallet at the day boundary;
offline catch-up (`offline_earnings.gd`) generalizes from a flat per-day rate to a
**sum over staffed stores**. **Invariant 3 (the day is the unit) is unchanged** — one
day still advances the whole chain at once; the day remains the save/idle unit.

### Forward hooks (named, not built in this epic's first slice)

The `Store` model must not *preclude* — but this ADR does not build — a `type` field
(kiosk → other store types) or a **maxed / front** flag. A maxed legit store becoming a
**front** is the coupling to the illegal layer (**invariant 5**); it is a later slice of
this epic, captured here only so the entity is shaped to receive it.

### Scope of the first build (the tracer-bullet issues)

A second **kiosk of the same type**: opened with clean money, switchable as the active
store, earning idle income when staffed, surfaced in a chain overview. **Vertical store
types, maxing, and the front / illegal coupling are explicitly later slices.**

## Consequences

**Positive**

- The chain becomes the visible reward of automation already proven fun — expansion and
  idle are the *same* mechanic, honoring invariants 2 and 4.
- A clean `Store` entity is the natural home for the stock / upgrades / rating state that
  `GameState` has been accreting; per-store logic becomes unit-testable in isolation, and
  the existing GameState-shaped injection means `Procure` / `Shift` need little change.
- Forward-compatible with fronts / laundering (invariant 5) and store types without
  committing to either now.

**Negative / accepted trade-offs**

- A **save-format migration (v2 → v3)**: existing flat fields wrap into `stores[0]`.
  One-time `from_dict` migration, then the v2 shape is retired.
- A refactor that touches every phase's "which store am I operating on" assumption.
  De-risked by shipping the model change **first with N=1 behaving identically**
  (invisible to the player — see issue slice 1).
- Per-store idle output needs a number — placeholder tuning, deferred like all economy
  numbers (`CONTEXT.md`); flag for an F5 feel pass.

**Neutral**

- The HUD grows a notion of "active store" plus a chain view; today's single-store HUD
  becomes the active-store HUD.

## Alternatives considered

- **Run every store's shift by hand each day** — rejected: doesn't scale past 2–3 stores
  and breaks the idle promise (invariant 4). Active play should be a *choice* of where to
  spend attention, never an obligation that grows linearly with the chain.
- **Stores fully abstracted to a per-day income formula once opened** — rejected: removes
  the active option (invariant 4 says automation *never replaces* the manual loop) and
  makes a new store a spreadsheet row, not a place to visit.
- **Per-store wallets with transfers** — rejected: violates "one continuous economy"
  (invariant 2) and adds banking busywork with no fun upside at this scale.
- **Defer the entity; bolt a second store onto the flat `GameState`** — rejected: the
  single-store assumptions are load-bearing across every phase and the save format. Bolting
  on N=2 without a `Store` entity smears store identity through every scene anyway; cheaper
  to extract the entity once, behind an invisible N=1 refactor.

## Notes

- Marked **Proposed**: this scopes the epic for ratification, written alongside the first
  tracer-bullet issues (GitHub #7+). Promote to **Accepted** once the model refactor (the
  first slice) lands and the approach holds.
- No `CONTEXT.md` invariant changes here; Expansion was already a documented pillar. If the
  "active store per day" rule proves load-bearing it may warrant its own glossary entry then.
