extends RefCounted
## ServeDriver — the first auto-serve clerk's pure, UI-free logic (v1).
##
## The clerk is the automation bridge (CONTEXT.md invariant 4): it *automates* the
## manual serve loop without ever *replacing* it. This driver is a brand-new
## *caller* of the existing Shift API, sitting beside serve.gd's click handler — it
## reads active_customer() and calls prep_step() / serve(id) exactly as a click
## would. It never touches Shift's serve()/prep_step() rule bodies, so the no-fail
## and no-double-serve safety lives in Shift, not in coordination between callers.
##
## Once hired (level >= 1), the clerk acts on a fixed cadence: it accumulates the
## frame delta and, each time it crosses a cadence boundary, performs exactly one
## service action against the *current* active customer. A hot dog costs it the same
## PREP_STEPS + 1 beats a human spends — it preps honestly, then hands over. The
## cadence is deliberately slower than the spawn interval at level 1, so the player
## can still out-serve it during a rush (the active option always stays meaningful).
##
## Deliberately decoupled from the scene and the autoload graph: the Shift is
## injected, the clerk level is read once at construction, and only the public Shift
## API is touched — so it unit-tests headlessly with the same StateStub style as the
## Shift itself (see tests/test_serve_driver.gd).

## Pulled in only for PRODUCTS (prep flag) and PREP_STEPS, which _act() reads to
## decide prep-vs-serve. No Shift is constructed here; the Shift is injected.
const ShiftScript := preload("res://scripts/phases/shift.gd")

## Seconds per service beat, by hired clerk level. Level 0 (or any level not in this
## table) never acts. Placeholder tuning (CONTEXT.md defers numbers): the whole curve
## sits at or near the shift's 2.5s spawn interval so the clerk stays a *helper*, never
## a replacement (CONTEXT.md invariant 4). L1 (3.0s) clearly falls behind a wave; even
## maxed L3 (2.2s) only drains a backlog on a lull, so a real rush always still pulls
## the player in. Higher levels keep the line steadier — they do NOT trivialise it.
## (Earlier L2=2.0/L3=1.2 outpaced the 2.5s spawn and instant-cleared waves — playtest.)
const CADENCE := {1: 3.0, 2: 2.6, 3: 2.2}

var _shift                    ## the Shift this clerk serves (injected, not owned)
var level: int = 0            ## hired clerk level; 0 = not hired
var _accum: float = 0.0       ## seconds accumulated toward the next beat


func _init(shift, p_level: int) -> void:
	_shift = shift
	level = p_level


## Seconds per service beat for the current level, or 0.0 when the level is not in
## CADENCE (i.e. not hired) — paired with is_active(), which gates the tick so an
## inactive clerk never reaches the cadence arithmetic.
func cadence() -> float:
	return float(CADENCE.get(level, 0.0))


## True iff the clerk is hired at a level that acts (level is in CADENCE).
func is_active() -> bool:
	return CADENCE.has(level)


## Accumulate delta and, for each crossed cadence boundary, perform exactly one
## service action via _act() (subtracting cadence each time). Returns true iff it
## actually served or prepped at least once this tick — a beat that lands on an
## empty queue, a stockout, or a wrong product is a benign no-op and does NOT count
## as having acted. A no-op (returns false) when the clerk is not hired or the
## shift is over.
func tick(delta: float) -> bool:
	if not is_active() or _shift.is_over:
		return false
	var beat := cadence()
	if beat <= 0.0:
		return false
	_accum += delta
	var acted := false
	while _accum >= beat:
		_accum -= beat
		if _act():
			acted = true
	return acted


## Exactly one service action against the *current* active customer, mirroring
## serve.gd's click routing: null/over -> nothing; an unprepped prep item -> one
## prep_step(); otherwise -> serve(active.product_id). Returns whatever the
## underlying Shift call returns (a harmless false on a stockout or empty queue),
## so a beat spent on a stockout/empty queue is a benign no-op, never a crash.
func _act() -> bool:
	if _shift.is_over:
		return false
	var c = _shift.active_customer()
	if c == null:
		return false
	if ShiftScript.PRODUCTS[c.product_id]["prep"] and _shift.prep_progress < ShiftScript.PREP_STEPS:
		return _shift.prep_step()
	return _shift.serve(c.product_id)
