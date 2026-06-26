extends SceneTree
## Headless test runner. Dependency-free; no GUT addon required.
##
## Run from the repo root:
##   godot --headless --script res://tests/run_tests.gd
##
## Exits 0 when every test passes and 1 when any fails, so CI and agents can
## gate on the exit code. Register new test scripts in TEST_SCRIPTS below.

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_game_state.gd",
	"res://tests/test_day_cycle.gd",
	"res://tests/test_shift.gd",
	"res://tests/test_procure.gd",
	"res://tests/test_upgrade.gd",
	"res://tests/test_serve_driver.gd",
]


func _initialize() -> void:
	var total := 0
	var failed := 0
	print("Running %d test script(s)...\n" % TEST_SCRIPTS.size())
	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			print("  ERROR  could not load %s" % path)
			failed += 1
			continue
		var case = script.new()
		var results: Dictionary = case.run()
		print("%s" % path)
		for line in results["log"]:
			print(line)
		total += int(results["total"])
		failed += int(results["failed"])
	print("\n%d test(s), %d failed." % [total, failed])
	quit(1 if failed > 0 else 0)
