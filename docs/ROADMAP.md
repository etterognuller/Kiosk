# Roadmap

How the design in `CONTEXT.md` gets built. The guiding principle is **scope discipline**: the
full game is large enough to be a multi-year solo effort, so it is treated as a **north star**,
not a v1 spec. Build the current phase only; resist pulling later systems forward.

The governing question for v1 is the only one that matters yet:
**"Is the 30-second core loop fun?"** If yes, everything else has a foundation. If no, we've
lost days, not months.

---

## Now — v1: the Tiniest Loop

The smallest build that answers the fun question. Placeholder/CC0 art. Money is the only number.

**In scope**

- One kiosk, one screen.
- ~3 products: cigarettes (instant), soda/candy (instant), hot dog (light prep).
- One day cycle: buy stock → open → serve a wave of customers → close → buy 1–2 upgrades →
  next day.
- Procurement: a simple "buy stock for tomorrow" step; stockouts mean lost sales.
- Serving: click instant items; one short prep step for the hot dog.
- 1–2 upgrades (e.g. faster register, add a product).
- Minimal save (money, stock, day, plus a timestamp for future offline calc).

**Explicitly NOT in v1**

- No chain / multiple locations, no automation/staff, no idle.
- No illegal layer, dirty money, laundering, or heat.
- No prestige/ascension or factions.
- No narrative, no audio, no custom art.

**Exit criteria:** the procure→serve→upgrade loop is genuinely enjoyable for ~10 minutes.

---

## Next — prove the genre shift

Only after v1 is fun. These validate the design's riskiest, most novel claim: that active play
graduates into idle.

- **Automation bridge:** hire the first clerk who auto-serves or auto-restocks — the literal
  mechanism that turns manual labor into idle.
- **Light progression:** multiple days, a small upgrade tree, a reputation/satisfaction number.
- **Second product tier** and the pakkeshop parcel line.
- **Offline earnings** measured in days away (uses the v1 timestamp).

**Exit criteria:** hiring staff *feels* like graduating from active to idle, without removing
the option to play actively.

---

## Later — the full north star

Built only once the core and the active→idle shift are proven. Each is a future epic, likely
its own ADR(s):

- **Expansion:** deepen → chain → vertical; maxing stores; multiple store types.
- **Two-currency economy:** clean vs. dirty money.
- **Illegal layer:** fronts, laundering, managed heat, the narrative reveal and protagonist.
- **Ascension/prestige:** reset for points + permanent upgrade tree.
- **Factions:** side with vs. outcompete the criminals.
- **"Adventures":** define and build the DAVE-style interactive episodes.
- **Polish:** custom pixel art, audio, narrative/dialogue, Danish flavor pass, mobile UI,
  economic tuning.

---

## Process notes

- Decisions that shape architecture get an ADR in `docs/adr/` (engine choice is ADR-0001).
- Work is tracked as GitHub issues via `gh` (see `docs/agents/issue-tracker.md`); the five
  triage labels are created on the remote (see `docs/agents/triage-labels.md`).
- Update `CONTEXT.md` when an open thread is resolved or an invariant changes.
