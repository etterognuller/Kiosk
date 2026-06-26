extends "res://tests/test_case.gd"
## Unit tests for the auto-serve clerk logic (scripts/phases/serve_driver.gd).
## These cover the v1 clerk acceptance criteria in docs/specs/clerk-v1.md and run
## headless, without the autoload graph: money/stock go through a tiny
## GameState-shaped stub, and the Shift's queue is hand-built (auto_spawn off) so
## the driver is exercised in isolation against the real Shift API. The catalog and
## round-trip tests additionally drive a *real* GameState to prove the "clerk" key
## buys, scales, maxes, and survives a to_dict/from_dict save like the other upgrades.

const ServeDriverScript := preload("res://scripts/phases/serve_driver.gd")
const ShiftScript := preload("res://scripts/phases/shift.gd")
const UpgradeShopScript := preload("res://scripts/phases/upgrade_shop.gd")
const GameStateScript := preload("res://scripts/globals/game_state.gd")


## A minimal stand-in for GameState: just the fields Shift reads/writes.
class StateStub extends RefCounted:
	var money: int = 0
	var stock: Dictionary = {}


## Returns [shift, state] with spawning off and an empty queue to populate, so the
## driver is the only thing moving the queue.
func _isolated(stock: Dictionary) -> Array:
	var state := StateStub.new()
	state.stock = stock
	var shift = ShiftScript.new(state)
	shift.auto_spawn = false
	return [shift, state]


## A driver bound to `shift` at clerk `level`. We do NOT call shift.start() here:
## start() unconditionally spawns the first customer (even with auto_spawn off),
## which would push an extra body onto our hand-built queue. is_over defaults to
## false, which is all the driver reads, so a started shift is unnecessary.
func _driver(shift, level: int):
	return ServeDriverScript.new(shift, level)


func test_level_zero_clerk_never_acts() -> void:
	var pair := _isolated({"cigarettes": 9, "soda": 9, "hotdog": 9})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [
		ShiftScript.Customer.new("soda", 999.0),
		ShiftScript.Customer.new("cigarettes", 999.0),
	]
	var driver = ServeDriverScript.new(shift, 0)
	assert_false(driver.is_active(), "level 0 is not active")
	var acted: bool = driver.tick(100.0)
	assert_false(acted, "tick did nothing")
	assert_eq(shift.served_count, 0, "served nothing")
	assert_eq(state.money, 0, "no money earned")
	assert_eq(shift.prep_progress, 0, "no prep happened")
	assert_eq(shift.queue.size(), 2, "queue unchanged")


func test_clerk_serves_instant_customer_after_one_beat() -> void:
	var pair := _isolated({"soda": 3})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("soda", 999.0)]
	var driver = _driver(shift, 1)  # cadence 3.0
	assert_false(driver.tick(2.9), "below cadence: no action")
	assert_false(shift.queue.is_empty(), "customer still waiting")
	assert_eq(state.money, 0, "no sale before the beat")
	var acted: bool = driver.tick(0.2)  # crosses 3.0
	assert_true(acted, "tick acted once it crossed the cadence")
	assert_eq(state.money, ShiftScript.PRODUCTS["soda"]["price"], "money += price")
	assert_eq(state.stock["soda"], 2, "stock -= 1")
	assert_eq(shift.served_count, 1, "served counted")
	assert_true(shift.queue.is_empty(), "customer left the queue")


func test_clerk_preps_then_serves_hotdog_over_prep_steps_plus_one_beats() -> void:
	var pair := _isolated({"hotdog": 1})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("hotdog", 999.0)]
	var driver = _driver(shift, 1)  # cadence 3.0
	# Beat 1: bun (one prep step), stock untouched.
	assert_true(driver.tick(3.0), "beat 1 acted")
	assert_eq(shift.prep_progress, 1, "prepped bun")
	assert_eq(state.stock["hotdog"], 1, "stock untouched after beat 1")
	assert_eq(shift.served_count, 0, "not served yet")
	# Beat 2: sausage — prep now complete, still not served.
	assert_true(driver.tick(3.0), "beat 2 acted")
	assert_eq(shift.prep_progress, ShiftScript.PREP_STEPS, "prep reached PREP_STEPS")
	assert_eq(state.stock["hotdog"], 1, "stock untouched after beat 2")
	assert_eq(shift.served_count, 0, "still not served before the hand-over beat")
	# Beat 3 (PREP_STEPS + 1): hand over.
	assert_true(driver.tick(3.0), "beat 3 acted")
	assert_eq(shift.served_count, 1, "served only after PREP_STEPS + 1 beats")
	assert_eq(state.stock["hotdog"], 0, "stock consumed on the sale")
	assert_eq(state.money, ShiftScript.PRODUCTS["hotdog"]["price"], "money += hot dog price")


func test_one_action_per_crossed_cadence_boundary() -> void:
	# A single tick that crosses exactly one cadence boundary acts exactly once,
	# even when delta slightly exceeds one cadence; the remainder carries over.
	var pair := _isolated({"soda": 9, "cigarettes": 9})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [
		ShiftScript.Customer.new("soda", 999.0),
		ShiftScript.Customer.new("cigarettes", 999.0),
	]
	var driver = _driver(shift, 1)  # cadence 3.0
	assert_true(driver.tick(3.4), "crossed one boundary")
	assert_eq(shift.served_count, 1, "exactly one action, not two, from a 3.4s tick")
	assert_eq(shift.queue.size(), 1, "only one customer served")
	# 0.4s carried over; a further 2.6s reaches the next 3.0 boundary.
	assert_true(driver.tick(2.6), "carried-over accumulator reaches the next beat")
	assert_eq(shift.served_count, 2, "second customer served on the next boundary")


func test_clerk_noop_on_empty_queue() -> void:
	var pair := _isolated({"soda": 9})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = []
	var driver = _driver(shift, 1)
	var acted: bool = driver.tick(30.0)  # several cadences
	assert_false(acted, "no action on an empty queue")
	assert_eq(state.money, 0, "money never went up")
	assert_eq(shift.served_count, 0, "served nothing")


func test_clerk_noop_on_stockout_is_lost_sale_never_negative() -> void:
	var pair := _isolated({"soda": 0})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("soda", 999.0)]
	var driver = _driver(shift, 1)  # cadence 3.0
	driver.tick(3.0)  # one beat -> serve() returns false on the stockout
	assert_eq(shift.lost_sales, 1, "stockout is a lost sale")
	assert_eq(shift.served_count, 0, "nothing served")
	assert_eq(state.money, 0, "no money for a stockout")
	assert_eq(state.stock["soda"], 0, "stock never went negative")
	assert_true(shift.queue.is_empty(), "the customer left the queue")


func test_clerk_noop_when_shift_over() -> void:
	var pair := _isolated({"soda": 9})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("soda", 999.0)]
	var driver = _driver(shift, 1)
	shift.is_over = true  # simulate the wave being cleared
	var acted: bool = driver.tick(30.0)
	assert_false(acted, "no action once the shift is over")
	assert_eq(shift.served_count, 0, "served nothing after shift end")
	assert_eq(state.money, 0, "no money after shift end")


func test_no_double_serve_with_manual_serve_same_frame() -> void:
	# The player manually serves customer A in the same frame the clerk's beat fires;
	# the clerk then serves the *new* active customer B — exactly two distinct sales,
	# never A twice, never a negative balance.
	var pair := _isolated({"soda": 9, "cigarettes": 9})
	var shift = pair[0]
	var state = pair[1]
	var cust_a := ShiftScript.Customer.new("soda", 999.0)
	var cust_b := ShiftScript.Customer.new("cigarettes", 999.0)
	shift.queue = [cust_a, cust_b]
	var driver = _driver(shift, 1)  # cadence 3.0
	# Manual serve clears A first (the click path).
	assert_true(shift.serve("soda"), "manual serve cleared customer A")
	assert_eq(shift.active_customer(), cust_b, "B is now the active customer")
	# The clerk's beat fires the same frame and serves B (re-reads active_customer).
	assert_true(driver.tick(3.0), "clerk acted on the new active customer")
	assert_eq(shift.served_count, 2, "exactly two distinct sales")
	assert_true(shift.queue.is_empty(), "both customers served, A never twice")
	assert_eq(state.money,
		ShiftScript.PRODUCTS["soda"]["price"] + ShiftScript.PRODUCTS["cigarettes"]["price"],
		"money consistent with two serves")
	assert_eq(state.stock["soda"], 8, "one soda consumed")
	assert_eq(state.stock["cigarettes"], 8, "one cigarettes consumed")


func test_clerk_double_serve_same_customer_is_harmless_noop() -> void:
	# Belt-and-braces: if two callers both fire serve() on the *same* active customer
	# (e.g. the clerk after a manual serve already popped them), the second is a
	# harmless no-op — never a second sale, never a negative balance. Here the clerk
	# serves the only customer, then an immediate second beat finds an empty queue.
	var pair := _isolated({"soda": 9})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new("soda", 999.0)]
	var driver = _driver(shift, 1)  # cadence 3.0
	assert_true(driver.tick(6.0), "two beats: serve then a no-op on the empty queue")
	assert_eq(shift.served_count, 1, "the single customer served exactly once")
	assert_eq(state.money, ShiftScript.PRODUCTS["soda"]["price"], "exactly one sale's money")
	assert_eq(state.stock["soda"], 8, "exactly one unit consumed")


func test_higher_level_acts_more_often() -> void:
	# Over the same elapsed time on a deep in-stock queue, level 3 (cadence 2.2)
	# serves strictly more customers than level 1 (cadence 3.0). The window is 12s so
	# the gap shows: L1 fits 4 beats, L3 fits 5 (a 6s window would tie at 2 each).
	var deep := []
	for i in range(20):
		deep.append("soda")
	var pair1 := _isolated({"soda": 99})
	var shift1 = pair1[0]
	shift1.queue = []
	for id in deep:
		shift1.queue.append(ShiftScript.Customer.new(id, 999.0))
	var driver1 = _driver(shift1, 1)  # cadence 3.0
	driver1.tick(12.0)

	var pair3 := _isolated({"soda": 99})
	var shift3 = pair3[0]
	shift3.queue = []
	for id in deep:
		shift3.queue.append(ShiftScript.Customer.new(id, 999.0))
	var driver3 = _driver(shift3, 3)  # cadence 2.2
	driver3.tick(12.0)

	assert_true(shift3.served_count > shift1.served_count,
		"level 3 served strictly more than level 1 over the same 12s")


func test_cadence_and_is_active_by_level() -> void:
	var pair := _isolated({})
	var shift = pair[0]
	assert_false(ServeDriverScript.new(shift, 0).is_active(), "level 0 not active")
	assert_true(ServeDriverScript.new(shift, 1).is_active(), "level 1 active")
	assert_eq(ServeDriverScript.new(shift, 1).cadence(), 3.0, "L1 cadence 3.0")
	assert_eq(ServeDriverScript.new(shift, 2).cadence(), 2.6, "L2 cadence 2.6")
	assert_eq(ServeDriverScript.new(shift, 3).cadence(), 2.2, "L3 cadence 2.2")
	assert_eq(ServeDriverScript.new(shift, 0).cadence(), 0.0, "L0 cadence sentinel 0.0")
	assert_false(ServeDriverScript.new(shift, 99).is_active(), "out-of-range level inert")


## A minimal stand-in for GameState's UpgradeShop fields (catalog tests).
class ShopStub extends RefCounted:
	var money: int = 0
	var upgrades: Dictionary = {}


func test_clerk_catalog_entry_buys_scales_and_maxes() -> void:
	var state := ShopStub.new()
	state.money = 9999
	var shop = UpgradeShopScript.new(state)
	assert_eq(shop.cost_of("clerk"), 100, "level 0 -> base 100")
	assert_true(shop.buy("clerk"), "hired level 1")
	assert_eq(shop.level_of("clerk"), 1, "level 1")
	assert_eq(shop.cost_of("clerk"), 400, "level 1 -> 100 + 300")
	assert_true(shop.buy("clerk"), "level 2")
	assert_eq(shop.cost_of("clerk"), 700, "level 2 -> 100 + 600")
	assert_true(shop.buy("clerk"), "level 3")
	assert_eq(shop.level_of("clerk"), 3, "reached max_level 3")
	assert_true(shop.is_maxed("clerk"), "is_maxed at the cap")
	assert_false(shop.buy("clerk"), "no purchase past max")
	assert_eq(shop.level_of("clerk"), 3, "level held at the cap")


func test_clerk_round_trips_through_game_state() -> void:
	# A hired clerk must survive a real GameState to_dict/from_dict save, like the
	# other upgrades — it is just another key in the upgrades dict.
	var gs = GameStateScript.new()
	gs.money = 9999
	var shop = UpgradeShopScript.new(gs)
	assert_true(shop.buy("clerk"), "clerk level 1")
	assert_true(shop.buy("clerk"), "clerk level 2")
	var snapshot: Dictionary = gs.to_dict()

	var restored = GameStateScript.new()
	restored.from_dict(snapshot)
	assert_eq(UpgradeShopScript.new(restored).level_of("clerk"), 2,
		"clerk level survived the save/load round-trip")


func test_clerk_not_affordable_day_one() -> void:
	# On a fresh GameState (50 kr) the clerk (100) cannot be hired — it must be earned.
	var gs = GameStateScript.new()
	gs.reset()
	var shop = UpgradeShopScript.new(gs)
	assert_eq(gs.money, GameStateScript.STARTING_MONEY, "fresh purse is STARTING_MONEY")
	assert_true(shop.cost_of("clerk") > GameStateScript.STARTING_MONEY,
		"clerk (100) costs more than day-1 money (50)")
	assert_false(shop.can_afford("clerk"), "cannot afford the clerk on day 1")
	assert_eq(shop.level_of("clerk"), 0, "fresh state starts with no clerk")
