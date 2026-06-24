extends "res://tests/test_case.gd"
## Smoke tests for DayCycle's phase machine. Tests the PROCURE→SERVE→UPGRADE
## transitions, which use only _set_phase (no GameState), so they run without the
## autoload graph. The UPGRADE→next-day rollover touches GameState and is left for
## an integration test once the loop has real content.

const DayCycleScript := preload("res://scripts/globals/day_cycle.gd")


func test_advance_steps_procure_to_serve_to_upgrade() -> void:
	var dc = DayCycleScript.new()
	dc.current_phase = DayCycleScript.Phase.PROCURE
	dc.advance()
	assert_eq(dc.current_phase, DayCycleScript.Phase.SERVE, "PROCURE -> SERVE")
	dc.advance()
	assert_eq(dc.current_phase, DayCycleScript.Phase.UPGRADE, "SERVE -> UPGRADE")
	dc.free()


func test_phase_name_matches_enum() -> void:
	var dc = DayCycleScript.new()
	assert_eq(dc.phase_name(DayCycleScript.Phase.PROCURE), "PROCURE")
	assert_eq(dc.phase_name(DayCycleScript.Phase.SERVE), "SERVE")
	assert_eq(dc.phase_name(DayCycleScript.Phase.UPGRADE), "UPGRADE")
	dc.free()


func test_phase_changed_signal_fires_once_per_advance() -> void:
	var dc = DayCycleScript.new()
	var seen: Array = []
	dc.phase_changed.connect(func(phase): seen.append(phase))
	dc.current_phase = DayCycleScript.Phase.PROCURE
	dc.advance()
	assert_eq(seen.size(), 1, "one emission")
	assert_eq(seen[0], DayCycleScript.Phase.SERVE, "emitted the new phase")
	dc.free()
