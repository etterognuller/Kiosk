# Kiosk

An incremental / management game inspired by older Flash titles such as *Hot Dog Bush*, *Learn to Fly*, and *Realm Grinder*. You run a kiosk / package shop (set in Denmark), serve and satisfy customers, expand the business, and make the number go up — with later branches into other (including illegal) endeavours.

## Agent skills

### Issue tracker

Issues are tracked in this repo's **GitHub Issues** via the `gh` CLI. External pull requests **are** treated as a triage request surface (a PR is an issue with attached code). See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` plus `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Engine & project layout

Godot **4.7** with **GDScript** (see `docs/adr/0001-godot-4.7-gdscript.md`). Use GDScript's
optional static typing. Key paths:

- `project.godot` — engine config. **Owned by the Godot editor**; prefer changing settings
  through the editor UI rather than hand-editing (it reformats the file and strips comments).
- `scripts/globals/` — autoload singletons: `GameState` (savable model + JSON save/load),
  `DayCycle` (the `PROCURE → SERVE → UPGRADE` phase state machine, emits `phase_changed` /
  `day_started`), `Game` (app controller, loads a save on boot).
- `scenes/Main.tscn` + `scripts/main.gd` — root scene; HUD plus a host that swaps in the
  current phase's scene on `phase_changed`.
- `scenes/phases/` + `scripts/phase_stub.gd` — placeholder screens for the three phases,
  replaced with real gameplay one phase at a time.
- `assets/{art,audio,fonts}/`, `ui/` — currently empty (`.gitkeep`).

The day is the structural unit (run / save point / offline measure). See `CONTEXT.md` for the
design spine and invariants, `docs/ROADMAP.md` for what's in scope now.

## Running & testing

`godot` must be on PATH. The editor was installed via Steam, which is **not** on PATH by
default — see `docs/dev-setup.md` for adding it (or use a standalone Godot 4.7 binary).

- **Open in the editor:** `godot --editor --path .`  (or just press **F5** in the editor to run).
- **Headless boot check** (catches parse/runtime errors without a window):
  `godot --headless --path . --quit-after 2 scenes/Main.tscn`
- **Run the test suite** (dependency-free headless runner; exits non-zero on failure, so it
  gates cleanly): `godot --headless --script res://tests/run_tests.gd`

Add a test in `tests/` for any new logic and run the suite before handing work back. The
runner and its assertions live in `tests/` (see `tests/README.md`); for richer reporting you
can later add the **GUT** addon under `addons/gut/` — the lightweight runner can coexist or be
replaced then.

**Important limit:** headless runs verify *errors and logic only* — they cannot judge feel.
The v1 question ("is the 30-second loop fun?") needs a human running the game with **F5**, so
flag anything that needs a play-feel check rather than assuming a green test means it's good.
