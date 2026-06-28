# CONTEXT

The domain language, core concepts, and design invariants for **Kiosk**. This is the
shared-understanding document: read it before reasoning about the game's design or code.
It captures *what the game is* and the non-negotiables behind it. Architectural choices
live in `docs/adr/`; what gets built when lives in `docs/ROADMAP.md`.

> Status: design spine agreed (2026-06-24). The full game is a long-term north star; only
> the v1 slice (see roadmap) is in scope to build. Numbers/tuning are deliberately undefined
> until the loop exists.

## Vision

A **cozy, no-fail management-incremental** about running a Danish kiosk that grows into a
small empire. The distinctive idea: the *dominant* loop deliberately evolves over a
playthrough, while remaining **one continuous economy** — there is never a hard genre break.

- **Early game** plays like *Hot Dog Bush*: hands-on, real-time customer service.
- **Mid game** layers in expansion and leveling like *Learn to Fly*: spend earnings to
  deepen and grow the business.
- **Late game** becomes an idle/incremental empire like *Realm Grinder*, with prestige and
  faction choices.
- **Throughout**, the warmth, characters, and art direction take after *DAVE THE DIVER*.

The engine that makes this work: your early **manual labor gradually becomes automated**
(by hiring staff), graduating the player from active play to idle without ever removing the
active option.

## Core loop — the Day

The **day** is the fundamental structural unit. It is the run, the save point, and the way
offline/idle time is measured ("3 days passed while you were away").

```
procure stock  →  open shop  →  serve customers  →  close  →  spend & upgrade  →  next day
```

## Pillars

**Serving (active).** Order-dependent hybrid. Packaged goods — cigarettes, soda, candy,
lottery, the pakkeshop parcel — are instant *grab-and-ring* transactions; managing the queue
and speed is the challenge. Signature items (hot dog, coffee) require a short **light prep**
step before serving. Upgrades target this directly: faster register, more prep stations,
self-service.

**Procurement (management).** Buying stock is its own mini-game played between/before days.
Keep levels healthy so you don't run out mid-shift. Later upgrades unlock bulk contracts,
supplier deals, and better margins.

**Expansion (the "number go up" spine).** Staged growth: **deepen** a flagship kiosk (more
product lines, more counters, hire clerks who automate serving/restocking) → build a
**chain** of locations → branch **vertically** into supply/distribution and new store types.
Stores can be **maxed out**, and a maxed legit store becomes a **front**.

**The illegal layer (late reveal).** Drips in narratively around a protagonist as legit
stores reach capacity. Legit fronts provide **laundering** throughput; illegal operations
generate **dirty money** that is useless until laundered clean. Governed by **managed heat**:
pushing illegal volume raises suspicion, laundering lowers it. High heat causes setbacks
(fines, a temporary raid/shutdown, losing some dirty cash) but **never a permanent loss** —
heat is a resource to balance, not a fail state.

**Ascension & factions (endgame).** Late game offers **ascension** — reset for prestige
points spent in a permanent upgrade tree (*Realm Grinder* prestige). A **faction fork** gives
the run an identity: **side with the criminals** or **outcompete them at their own game**.

## Tone & art

Cozy and no-fail. Customers waiting cost you money and reputation, never the game; a bad day
just slows progress so the incremental promise (the number eventually goes up) always holds.
Art is **bit-style** in the spirit of *DAVE THE DIVER*. Production reality: **placeholder /
CC0 pixel art now, custom art later** (drawing it all by hand is the dream, not the plan).

## Glossary

- **Kiosk** — the starting business; a small Danish convenience shop.
- **Pakkeshop** — package/parcel pickup-and-drop point; a real Danish kiosk staple and one of
  the early product lines.
- **Shift** — the active, real-time serving portion of a day.
- **Light prep** — the short multi-step preparation for signature items (hot dog, coffee)
  before a customer can be served.
- **Store rating** — the shop's customer score, shown Trustpilot-style as 1–5 stars. A
  Bayesian average of per-customer reviews (a prompt serve scores high, a lost sale scores
  low), summed at day's end; a fresh store is *Unrated* and earns its rating through service.
  Rating gates content: a line like the parcel pakkeshop only unlocks once the store's
  best-ever rating earns it (sticky — it won't re-lock). Further payoff (a popularity
  currency, volume) is deferred (see ROADMAP "Later").
- **Clerk / staff** — hired workers who automate serving or restocking; the bridge from
  active play to idle.
- **Clean money** — ordinary, spendable currency from legitimate sales.
- **Dirty money** — illicit currency that cannot be spent until laundered.
- **Front** — a legitimate (often maxed) store used to launder dirty money; provides
  laundering throughput.
- **Laundering** — converting dirty money to clean via front capacity.
- **Heat** — a suspicion meter; rises with illegal volume, falls with laundering; high heat
  triggers non-permanent setbacks.
- **Ascension** — prestige reset that grants points for a permanent upgrade tree.
- **Faction** — the late-game path choice (join vs. outcompete the criminals).

## Design invariants (do not violate without an ADR)

1. **No-fail / cozy.** No permanent game-over, ever — including in the criminal late game.
2. **One continuous economy.** No hard genre break between active, management, and idle phases.
3. **The day is the unit.** Save points, upgrade cadence, and offline time are all day-based.
4. **Automation is the bridge.** Idle is earned by automating prior manual loops, not by
   replacing them — the active option always remains.
5. **Legit serves the illegal.** Legit stores' end purpose is laundering capacity; the two
   economies are coupled by design.
6. **Scope discipline.** The full design is a north star. Build only what the current roadmap
   phase scopes. See `docs/ROADMAP.md`.

## Open threads (unresolved as of 2026-06-24)

- **"Adventures"** — DAVE-style interactive episodes were floated but undefined; likely the
  illegal deals/supply-runs. Resolve when that phase is reached.
- **Protagonist & narrative depth** — a protagonist arc is implied; amount of story/dialogue
  is undecided. Not needed for v1.
- **Language** — setting is Denmark. Working assumption: English UI with Danish flavor
  (pakkeshop, pølser, Dankort, Danish town names).
- **Save system** — trivial for v1, but offline-as-days needs a stored timestamp from day one.
- **Audio** — deferred; source CC0 SFX later.
- **Economic tuning** — all numbers deferred until the loop exists.
