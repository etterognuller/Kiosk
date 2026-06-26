extends "res://tests/test_case.gd"
## Unit tests for the SERVE shift logic (scripts/phases/shift.gd). These cover the
## v1 acceptance criteria in docs/specs/serve-v1.md and run headless, without the
## autoload graph: money/stock go through a tiny GameState-shaped stub, and the
## queue is hand-built (auto_spawn off) so each rule is exercised in isolation.

const ShiftScript := preload("res://scripts/phases/shift.gd")
const DayCycleScript := preload("res://scripts/globals/day_cycle.gd")


## A minimal stand-in for GameState: just the fields Shift reads/writes.
class StateStub extends RefCounted:
	var money: int = 0
	var stock: Dictionary = {}
	var reputation: int = 50


func _isolated(stock: Dictionary) -> Array:
	# Returns [shift, state] with spawning off and an empty queue to populate.
	var state := StateStub.new()
	state.stock = stock
	var shift = ShiftScript.new(state)
	shift.auto_spawn = false
	return [shift, state]


func test_serve_in_stock_adds_money_and_decrements_stock() -> void:
	var pair := _isolated({"soda": 3})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("soda", 10.0)]
	var ok: bool = shift.serve("soda")
	assert_true(ok, "serve succeeded")
	assert_eq(state.money, ShiftScript.PRODUCTS["soda"]["price"], "money += price")
	assert_eq(state.stock["soda"], 2, "stock -= 1")
	assert_eq(shift.served_count, 1, "served counted")
	assert_true(shift.queue.is_empty(), "active customer left the queue")


func test_serve_out_of_stock_is_lost_sale_and_never_negative() -> void:
	var pair := _isolated({"soda": 0})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("soda", 10.0)]
	var ok: bool = shift.serve("soda")
	assert_false(ok, "no sale on stockout")
	assert_eq(state.stock["soda"], 0, "stock did not go negative")
	assert_eq(state.money, 0, "no money for a stockout")
	assert_eq(shift.lost_sales, 1, "registered a lost sale")
	assert_eq(shift.served_count, 0, "nothing served")


func test_wrong_product_is_a_harmless_noop() -> void:
	var pair := _isolated({"soda": 1, "cigarettes": 1})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("soda", 10.0)]
	var ok: bool = shift.serve("cigarettes")
	assert_false(ok, "wrong product is not a sale")
	assert_eq(state.stock["cigarettes"], 1, "untouched stock")
	assert_eq(state.money, 0, "no money")
	assert_false(shift.queue.is_empty(), "customer still waiting")
	assert_eq(shift.lost_sales, 0, "not a lost sale either")


func test_hotdog_cannot_be_served_before_prep_is_complete() -> void:
	var pair := _isolated({"hotdog": 1})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("hotdog", 10.0)]
	assert_false(shift.serve("hotdog"), "cannot serve an un-prepped hot dog")
	assert_eq(state.stock["hotdog"], 1, "stock untouched before prep")
	assert_true(shift.prep_step(), "bun")
	assert_false(shift.serve("hotdog"), "still not fully prepped after one step")
	assert_true(shift.prep_step(), "sausage")
	assert_false(shift.prep_step(), "no prep beyond PREP_STEPS")
	assert_true(shift.serve("hotdog"), "now it hands over")
	assert_eq(state.stock["hotdog"], 0, "stock consumed on the sale")
	assert_eq(shift.served_count, 1, "served counted")


func test_patience_expiry_is_a_lost_sale() -> void:
	var pair := _isolated({"soda": 5})
	var shift = pair[0]
	shift.queue = [ShiftScript.Customer.new("soda", 1.0)]
	shift.tick(2.0)  # exceeds the customer's patience
	assert_true(shift.queue.is_empty(), "impatient customer left")
	assert_eq(shift.lost_sales, 1, "counted as a lost sale")
	assert_eq(shift.served_count, 0, "nothing served")


func test_serve_raises_reputation() -> void:
	var pair := _isolated({"soda": 1})
	var shift = pair[0]
	var state = pair[1]
	state.reputation = 50
	shift.queue = [ShiftScript.Customer.new("soda", 10.0)]
	assert_true(shift.serve("soda"), "served")
	assert_eq(state.reputation, 50 + ShiftScript.REP_PER_SERVE, "a serve nudged reputation up")


func test_stockout_lowers_reputation() -> void:
	var pair := _isolated({"soda": 0})
	var shift = pair[0]
	var state = pair[1]
	state.reputation = 50
	shift.queue = [ShiftScript.Customer.new("soda", 10.0)]
	assert_false(shift.serve("soda"), "stockout: no sale")
	assert_eq(state.reputation, 50 - ShiftScript.REP_PER_LOST_SALE, "a stockout nudged reputation down")


func test_patience_expiry_lowers_reputation() -> void:
	var pair := _isolated({"soda": 5})
	var shift = pair[0]
	var state = pair[1]
	state.reputation = 50
	shift.queue = [ShiftScript.Customer.new("soda", 1.0)]
	shift.tick(2.0)  # the customer's patience runs out -> a lost sale
	assert_eq(shift.lost_sales, 1, "patience expiry counted as a lost sale")
	assert_eq(state.reputation, 50 - ShiftScript.REP_PER_LOST_SALE, "an expiry nudged reputation down")


func test_reputation_never_drops_below_floor() -> void:
	# No-fail / cozy: a bad run pins reputation at the floor, never below, never a crash.
	var pair := _isolated({"soda": 0, "cigarettes": 0})
	var shift = pair[0]
	var state = pair[1]
	state.reputation = 1  # one point above the floor, less than one loss step
	shift.queue = [
		ShiftScript.Customer.new("soda", 10.0),
		ShiftScript.Customer.new("cigarettes", 10.0),
	]
	shift.serve("soda")        # stockout -> down, clamps at the floor
	shift.serve("cigarettes")  # another stockout -> stays at the floor
	assert_eq(state.reputation, ShiftScript.REP_MIN, "reputation clamped at the floor")
	assert_true(state.reputation >= 0, "reputation never went negative")


func test_reputation_never_exceeds_ceiling() -> void:
	var pair := _isolated({"soda": 5})
	var shift = pair[0]
	var state = pair[1]
	state.reputation = ShiftScript.REP_MAX  # already maxed
	shift.queue = [
		ShiftScript.Customer.new("soda", 10.0),
		ShiftScript.Customer.new("soda", 10.0),
	]
	shift.serve("soda")
	shift.serve("soda")
	assert_eq(state.reputation, ShiftScript.REP_MAX, "reputation clamped at the ceiling")


func test_fixed_wave_ends_and_emits_shift_ended_once() -> void:
	var state := StateStub.new()
	state.stock = {"cigarettes": 99, "soda": 99, "hotdog": 99}
	var shift = ShiftScript.new(state)
	shift.wave_size = 3
	shift.spawn_interval = 0.0  # let the whole wave arrive immediately
	var ended := [0]
	shift.shift_ended.connect(func(): ended[0] += 1)
	shift.start()       # customer 1 arrives
	shift.tick(0.0)     # customer 2
	shift.tick(0.0)     # customer 3 — whole wave has now arrived
	assert_false(shift.is_over, "not over while customers remain")
	# Serve everyone (prep the hot dog when it comes up).
	while not shift.queue.is_empty():
		var c = shift.active_customer()
		if ShiftScript.PRODUCTS[c.product_id]["prep"]:
			shift.prep_step()
			shift.prep_step()
		shift.serve(c.product_id)
	assert_true(shift.is_over, "shift ended once the wave was cleared")
	assert_eq(shift.served_count, 3, "served the whole wave")
	assert_eq(ended[0], 1, "shift_ended fired exactly once")


func test_shift_end_advances_the_day_cycle_exactly_once() -> void:
	# Acceptance: the end condition triggers exactly one DayCycle.advance()
	# (SERVE -> UPGRADE). Wire a real DayCycle to the shift, no scene needed.
	var dc = DayCycleScript.new()
	dc.current_phase = DayCycleScript.Phase.SERVE
	var changes := []
	dc.phase_changed.connect(func(p): changes.append(p))
	var state := StateStub.new()
	state.stock = {"cigarettes": 9}
	var shift = ShiftScript.new(state)
	shift.wave_size = 1
	shift.shift_ended.connect(dc.advance)
	shift.start()                  # one cigarettes customer arrives
	shift.serve("cigarettes")      # clears the wave -> shift_ended -> advance()
	assert_true(shift.is_over, "shift ended")
	assert_eq(dc.current_phase, DayCycleScript.Phase.UPGRADE, "SERVE -> UPGRADE")
	assert_eq(changes.size(), 1, "exactly one phase change")
	assert_eq(changes[0], DayCycleScript.Phase.UPGRADE, "advanced to UPGRADE")
	dc.free()
