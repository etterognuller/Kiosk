# Build brief — First clerk: auto-serve (v1)

> The "Next — prove the genre shift" headline from `docs/ROADMAP.md`: **hire the first clerk
> who auto-serves — the literal mechanism that turns manual labor into idle.** Scope is one
> clerk, nothing more. See `CONTEXT.md` (Automation is the bridge, invariant 4) and the
> existing `docs/specs/serve-v1.md` for the loop this grafts onto.

## Why this one matters

v1 proved the 30-second serve loop is fun. This slice proves the design's **riskiest, most
novel claim**: that active play **graduates into idle** — and that it does so by *automating*
the manual serve loop, **never replacing it**. A hired clerk serves the same queue, through the
same `Shift` API, while the player can still click to serve faster. If hiring the clerk feels
like *earning a helper you can lean on* (and still want to jump in during a rush), the
active→idle bridge works. That is a **feel** question; tests prove only correctness.

## Goal

Add the first **auto-serve clerk**: a persistent, paid hire that, once owned, serves the
front/active customer on a fixed cadence during the SERVE shift — alongside the player, who
keeps the full manual serve option. Hiring lives in the UPGRADE phase like any other upgrade;
the clerk takes effect from the next shift.

## In scope

- **One** leveled clerk (level 0 = not hired; levels 1–3 = faster cadence). Hired from the
  existing UPGRADE catalog.
- A new, headless-testable **`ServeDriver`** (`RefCounted`) that is a *new caller* of the
  existing `Shift` API — it reads `active_customer()` and calls `prep_step()` / `serve(id)`
  exactly as the click path does. No change to `shift.gd`'s serve logic.
- The clerk acts on a **cadence** (one service action per beat), so it is visibly slower than a
  focused human and the player can out-pace it.
- The clerk handles the **hot dog** honestly: prep then serve, one beat per step, so a hot dog
  costs it `PREP_STEPS + 1` beats — the same work the player does.
- Persistence folds into the **existing** `GameState.upgrades` dict + `UpgradeShop.CATALOG`
  (zero new GameState field, zero new serialization code).

## Out of scope (v1 clerk slice)

No auto-**restock** clerk. No second clerk / multiple bodies / lanes. No idle-offline math, no
reputation/satisfaction number, no narrative. The clerk does **not** gate, disable, or hide the
manual serve buttons. Numbers are placeholder tuning (`CONTEXT.md` defers tuning). Resist
pulling any of the "Later" roadmap forward.

## Interaction & persistence

**Hiring (UPGRADE phase).** The clerk is a `CATALOG` entry, so `upgrade.gd` renders its row,
Buy button, cost scaling, affordability gating and MAX state with **zero new UI code**. Hiring
spends `GameState.money` and raises `GameState.upgrades["clerk"]` through the existing no-fail
`UpgradeShop.buy()` — unaffordable/maxed is a harmless no-op, money/levels never go negative.

**Persistence (day boundary).** `"clerk"` is just another key in `GameState.upgrades`, which
`to_dict()`/`from_dict()` already serialize verbatim — so the clerk level round-trips through a
save with no new serialization code (the existing cross-seam round-trip pattern already proves
the dict survives). Old saves missing the key read as level 0 (`UpgradeShop.level_of` tolerates
a missing key). The clerk reads its level **once** at shift start, so a clerk hired mid-UPGRADE
takes effect the **next** shift (invariant 3: the day is the unit).

**Serving (SERVE phase).** Each frame, `serve.gd._process` ticks the shift, then ticks the
driver, then refreshes. The driver accumulates `delta`; each time it reaches its cadence it
performs **exactly one** service action against the **current** `active_customer()`:

1. `active_customer()` is null **or** `shift.is_over` → do nothing.
2. active wants a prep item and `prep_progress < PREP_STEPS` → one `prep_step()`, stop.
3. otherwise → `serve(active.product_id)`.

**Manual + auto coexist, no double-serve race.** The product buttons and their `_serve()`
handler are untouched; the driver is a *second caller*, not a gate. Safety lives in `Shift`,
not in coordination between callers: `serve()` pops the active customer atomically on success
and resets prep; `prep_step()` caps at `PREP_STEPS`. GDScript `_process` is single-threaded and
runs each call to completion, so if the clerk and a human act in the same frame the calls are
strictly serial — whoever lands first serves customer A, the second re-reads a **new**
`active_customer()` (or null) and either serves the next person or returns a harmless `false`.
Never a negative balance, never a stock under-run (`serve()` guards `on_hand <= 0`), never the
same customer served twice. A human finishing a hot dog the clerk started (or vice-versa) just
works, because prep is shared state on the one active order.

## Architecture fit

- **NEW** `scripts/phases/serve_driver.gd` — `ServeDriver extends RefCounted`. Pure logic, no
  Node/scene/autoload dependency, unit-tested with the same StateStub style as `test_shift.gd`.
  It holds the injected `Shift`, the clerk `level`, and a `float` accumulator; it touches only
  the **public** `Shift` API. It is the literal proof that auto-serve is a *new caller*, sitting
  beside `serve.gd`'s click handler.
- **EDIT** `scripts/phases/serve.gd` — build the driver in `_ready()` (reading the clerk level
  via `UpgradeShop`), and tick it in `_process()` after `_shift.tick(delta)` and before
  `_refresh()`. The driver lives and dies with the shift (and halts when `set_process(false)`
  fires at shift end). This input layer is the sanctioned place to add a caller per the
  serve-interaction roadmap.
- **EDIT** `scripts/phases/upgrade_shop.gd` — add one `"clerk"` `CATALOG` entry. The clerk maps
  to driver **cadence**, not a `Shift` field, so it deliberately does **not** flow through
  `apply_to_shift` (leave that method as-is). `buy`/`cost_of`/`is_maxed`/`can_afford`/`level_of`
  are id-generic and work unchanged. One-line comment on the entry: `target` is `""` because
  the clerk is driver-owned, not a Shift offset.
- **EDIT** `scripts/globals/game_state.gd` — add `"clerk": 0` to the `upgrades` dict in both the
  field initializer and `reset()`. `to_dict`/`from_dict` are **untouched**.
- **NOTHING** in `upgrade.gd` / `Upgrade.tscn` / `Serve.tscn` — the CATALOG fold renders the
  Hire row for free; the manual buttons are untouched.

## Tuning placeholders (all deferred per `CONTEXT.md` — sized against the existing shift)

Existing shift shape: `DEFAULT_SPAWN_INTERVAL` 2.5s, `DEFAULT_PATIENCE` 10s, `DEFAULT_WAVE_SIZE` 8.

- **Cadence (seconds per service beat):** L1 = 3.0, L2 = 2.6, L3 = 2.2 (retuned after the first
  playtest — see note below). The whole curve sits at or near the 2.5s spawn interval, so the
  clerk stays a *helper*, never a replacement: L1 (3.0s) clearly falls behind a wave, and even
  maxed L3 (2.2s) only drains a backlog on a lull — a real rush always still pulls the player in.
  Higher levels keep the line steadier without trivialising it. A hot dog still costs the clerk
  `PREP_STEPS + 1` = 3 beats, so a focused human out-races it on prep items. The active option
  stays meaningful at **every** level.
  - *Playtest note (2026-06-26):* the original L2 = 2.0 / L3 = 1.2 **outpaced** the 2.5s spawn
    and instant-cleared whole waves (felt overpowered). Flattening the curve to stay near the
    spawn rate restored the "step in during a rush" feel at all levels.
- **Hire cost / scaling:** `base_cost` 100, `cost_step` 300, `max_level` 3 (L1 100, L2 400,
  L3 700; maxing = 1200 kr total). Retuned up from 60/40 after the first playtest: the clerk is
  a **long-term idle unlock**, so each level is several days of takings, not pocket change.
  `base_cost` 100 is above `STARTING_MONEY` (50), so even the first hire is earned over a couple
  of shifts; reaching a steady auto-served shift is a multi-day goal that competes for the same
  kroner as `counter_space` / `loyalty_cards`.
- **Hot-dog cost** reuses the existing `PREP_STEPS` (2); the clerk adds no new constant.

These keep the manual option strictly meaningful while making the clerk a visible income floor.

## Acceptance criteria

**Logic (headless-testable in `tests/`):**

- A level-0 clerk **never acts** (no serve, no prep), no matter how long it is ticked.
- A clerk serves the active **instant** customer after one cadence beat: money up, that
  product's stock down by 1, `served_count` up, customer leaves the queue.
- A clerk **preps then serves** a hot dog over exactly `PREP_STEPS + 1` beats (bun, sausage,
  hand over) — it does not skip prep, and does not serve early.
- Cadence is honored: below the cadence the clerk does **not** act; ticking past it acts once;
  it does not perform two actions from one over-large tick that only crosses one boundary
  (one action per crossed cadence boundary).
- The clerk is a harmless no-op on an **empty queue**, on a **stockout** (a lost sale, money
  and stock never negative), and when the **shift is over**.
- **No double-serve:** with the active customer already served by a manual call in the same
  frame, the clerk's tick serves the *next* customer or no-ops — never the same customer twice,
  never a negative balance.
- A higher cadence level acts **strictly more often** than a lower one over the same elapsed
  time (level monotonicity).
- The `"clerk"` CATALOG entry **buys, scales, maxes, and round-trips** through a real
  `GameState` (`to_dict`/`from_dict`) like the other upgrades; a fresh `GameState` (50 kr)
  **cannot** afford the clerk on day 1 (it must be earned).

**Feel (human, F5 — cannot be unit-tested):**

- Hiring the clerk feels like **earning a helper you can lean on** — you can stop clicking,
  watch the queue still drain and money still tick up — **and** still want to jump in during a
  rush. The one F5 question that decides success: *"When I hire the clerk, do I feel like I
  EARNED a helper I can lean on (and still want to jump in during a rush) — rather than feeling
  the game now plays itself, or that clicking is now pointless?"*
- The cadence reads as a worker with hands (you can watch it work a hot dog bun → sausage →
  hand over), not an instant clear. Cadence/cost numbers will almost certainly need a tuning
  pass after one session — flag, do not claim.

## References

- `CONTEXT.md` — invariant 4 (Automation is the bridge), invariant 1 (no-fail/cozy), invariant 3
  (the day is the unit), Glossary: *Clerk / staff*.
- `docs/ROADMAP.md` — "Next — prove the genre shift" (automation bridge, exit criteria).
- `docs/specs/serve-v1.md` — the serve loop this grafts onto.
- `scripts/phases/shift.gd` — the `Shift` API the driver calls (`active_customer`, `prep_step`,
  `serve`, `prep_progress`, `is_over`, `PRODUCTS`, `PREP_STEPS`).
- `scripts/phases/upgrade_shop.gd`, `scripts/globals/game_state.gd` — the purchase + persistence
  machinery the clerk reuses verbatim.
