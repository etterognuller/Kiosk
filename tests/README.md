# Tests

A small, dependency-free headless test harness for the GDScript logic. No addon
required, so it runs straight from a clean checkout.

## Run

From the repo root (with `godot` on PATH — see `docs/dev-setup.md`):

```bash
godot --headless --script res://tests/run_tests.gd
```

Exit code is `0` when all tests pass and `1` when any fail, so it gates cleanly in
CI or an agent loop. Output lists each `PASS`/`FAIL` and a final count.

## Layout

- `run_tests.gd` — the runner (a `SceneTree` script). Register new test files in its
  `TEST_SCRIPTS` array.
- `test_case.gd` — assertion base (`assert_eq`, `assert_true`, `assert_false`). Subclass it.
- `test_*.gd` — one file per unit under test; methods named `test_*` run automatically.

## Writing a test

```gdscript
extends "res://tests/test_case.gd"

const Thing := preload("res://scripts/thing.gd")

func test_does_the_thing() -> void:
    var t = Thing.new()
    assert_eq(t.value(), 42, "optional note")
```

Tests should run **without the autoload graph** where possible: instantiate the script under
test directly (`Script.new()`) instead of relying on the `GameState`/`DayCycle` singletons, and
avoid writing real files (don't call `save_game()` against the live `user://savegame.json`).
For state that needs a temp file or the full singleton graph, write an integration test that
sets up its own paths.

## Upgrading to GUT

If you later want richer assertions, fixtures, and reporting, add the
[GUT](https://github.com/bitwes/Gut) addon under `addons/gut/` (Godot 4 branch). This harness
can coexist with GUT or be retired in its favour — keep whichever serves the loop better.
