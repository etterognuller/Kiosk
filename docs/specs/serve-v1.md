# Build brief — Serve phase (v1)

> Drop this into a GitHub issue (`gh issue create`) to give the build a clear target, or work
> from it directly. Scope is intentionally tight; see `CONTEXT.md` (Serving pillar) and
> `docs/ROADMAP.md` (Now — v1).

## Why this one matters

Serve is the phase the whole v1 bet rides on: **"is the 30-second core loop fun?"** Everything
else in the game is scaffolding around this interaction. Build the smallest version that can
answer that, then iterate on feel.

## Goal

Turn the `SERVE` phase stub into a real, playable shift: customers arrive wanting products, the
player serves them, money goes up and stock goes down, and the shift ends so the day can roll
on to `UPGRADE`.

## In scope

- A wave of customers for one shift (the SERVE phase between PROCURE and UPGRADE).
- The three v1 products: **cigarettes** (instant), **soda** (instant), **hot dog** (light prep).
- An **instant** serve path (grab-and-ring) and a **light-prep** path (a short multi-step
  action before the hot dog can be handed over).
- Each successful serve adds money (`GameState.money`) and consumes one unit of stock
  (`GameState.stock`). **Stockout = lost sale**, not a crash.
- The shift ends on a clear condition (see "Shift structure"), returning control to the day loop
  via `DayCycle.advance()`.
- Minimal feedback: a customer's order is visible, and a serve visibly resolves (served / left).

## Out of scope (v1)

No staff/automation, no reputation/satisfaction number yet, no multiple counters, no upgrades
wired into serving, no audio, no custom art (placeholder shapes/labels are fine). No idle, no
illegal layer. Resist pulling later systems forward.

## Proposed interaction model — *confirm before building*

**Click-to-serve** (Hot Dog Bush / cozy-counter feel):

- A waiting customer shows an order (icon/label for the product).
- The player clicks the matching product to serve an instant item.
- For the hot dog, the player first clicks through a short **prep** (e.g. bun → sausage →
  hand over) — a couple of clicks, not a minigame — then serves.
- The challenge is **queue management and speed**, not precision.

This is the recommended default because it fits the cozy, click-driven direction and the
existing UI-first scenes. Alternatives considered and set aside for v1: keyboard hotkeys (more
arcade, less cozy) and drag-to-customer (fiddlier). **Asger to confirm** this is the model
before significant code goes in.

## Customer & order model (starting point — tune later)

- Customers spawn into a small visible queue (front customer is the active one).
- Each customer wants exactly **one** product in v1.
- Each customer has a **patience timer**; if it runs out before being served, they leave (lost
  sale). Patience values are placeholders — tune for feel, don't optimise yet.
- Numbers (spawn rate, patience, wave size, prices) are deliberately undefined in `CONTEXT.md`
  until the loop exists. Start with whatever makes a ~30-second shift readable and adjust.

## Shift structure

Pick the simpler of these and note the choice in the issue:

- **Fixed wave:** serve N customers, then the shift ends. Deterministic, easy to test.
- **Timed shift:** a short countdown (e.g. ~30–60s); serve as many as you can, then it ends.

Either way, ending the shift calls `DayCycle.advance()` (SERVE → UPGRADE). Keep the end
condition explicit so a headless test can drive it.

## Architecture fit

- Build inside `scenes/phases/Serve.tscn` + a new `scripts/phases/serve.gd` (replace the shared
  `phase_stub.gd` for this phase). `main.gd` already instantiates the phase scene on
  `phase_changed` — no change needed there.
- Read/write money and stock through **`GameState`** only (single source of truth; it's what
  saves). Don't add a parallel economy.
- Advance the loop through **`DayCycle.advance()`**; don't bypass the state machine.
- Keep serving logic separable from its UI so it can be unit-tested without a running scene
  (e.g. a plain `RefCounted` "shift"/"register" object the scene drives), per `tests/README.md`.

## Acceptance criteria

Logic (headless-testable in `tests/`):

- Serving an in-stock product increases `GameState.money` and decreases that product's stock by 1.
- Serving when that product is out of stock does **not** go negative and registers a lost sale.
- The hot dog cannot be served before its prep steps are complete.
- The shift's end condition fires and triggers exactly one `DayCycle.advance()` (SERVE → UPGRADE).

Feel (human, F5 — cannot be unit-tested):

- A shift reads clearly and plays in roughly 30 seconds.
- Serving feels responsive and a little bit busy — the core "is this fun?" check.

## Open decisions to confirm with Asger

1. Interaction model = click-to-serve? (proposed above)
2. Shift = fixed wave or timed?
3. Do customers queue in a line, or appear at one active slot, for v1?

## References

- `CONTEXT.md` — Serving pillar, invariants (no-fail/cozy, one continuous economy, the day is
  the unit).
- `docs/ROADMAP.md` — Now (v1) scope and exit criteria.
- `scripts/globals/game_state.gd`, `scripts/globals/day_cycle.gd` — the model and the FSM to
  build against.
