extends Node
## DayCycle — the day's phase state machine.
##
## The day is the fundamental structural unit (CONTEXT.md). The full loop is:
##
##   procure stock → open shop → serve customers → close → spend & upgrade → next day
##
## For v1 the three *interactive* phases are PROCURE, SERVE and UPGRADE. "Open"
## and "close" are momentary transitions folded into entering and leaving SERVE,
## so they don't get their own screens yet. The FSM owns the current phase and
## announces changes via signals; the UI listens and swaps in the matching scene.
##
## This script is the wiring only — no real gameplay lives here yet.

## Emitted whenever the active phase changes. `phase` is a Phase enum value.
signal phase_changed(phase: int)

## Emitted at the start of each day (including day 1), after the day counter is set.
signal day_started(day: int)

enum Phase { PROCURE, SERVE, UPGRADE }

var current_phase: int = Phase.PROCURE


## Begin the loop at the first phase of the current day. Call once after the UI
## has connected its listeners (Main does this in _ready).
func start() -> void:
	current_phase = Phase.PROCURE
	day_started.emit(GameState.day)
	phase_changed.emit(current_phase)


## Advance to the next phase, rolling over to the next day after UPGRADE.
func advance() -> void:
	match current_phase:
		Phase.PROCURE:
			_set_phase(Phase.SERVE)    # "open shop"
		Phase.SERVE:
			_set_phase(Phase.UPGRADE)  # "close shop"
		Phase.UPGRADE:
			_end_day()


## Human-readable name for a phase, handy for the HUD and debugging.
func phase_name(phase: int = current_phase) -> String:
	return Phase.keys()[phase]


func _set_phase(phase: int) -> void:
	current_phase = phase
	phase_changed.emit(current_phase)


func _end_day() -> void:
	GameState.day += 1
	GameState.save_game()  # the day boundary is the save point
	current_phase = Phase.PROCURE
	day_started.emit(GameState.day)
	phase_changed.emit(current_phase)
