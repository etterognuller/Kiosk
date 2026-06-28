extends "res://tests/test_case.gd"
## Unit tests for the pakkeshop parcel line (issue #4) — the first product added
## end-to-end after v1. Parcels reuse the generic Procure/Shift paths, so these
## tests pin the wiring: parcels are procurable at a margin, serve as an instant
## grab-and-ring sale, a stockout is a no-fail lost sale, a parcel customer can
## actually arrive during a shift, and parcel stock survives a save round-trip.

const ProcureScript := preload("res://scripts/phases/procure.gd")
const ShiftScript := preload("res://scripts/phases/shift.gd")
const GameStateScript := preload("res://scripts/globals/game_state.gd")

const PARCEL := "parcels"


class StateStub extends RefCounted:
	var money: int = 0
	var stock: Dictionary = {}


func test_parcels_are_in_both_catalogs_as_an_instant_good() -> void:
	assert_true(ShiftScript.PRODUCTS.has(PARCEL), "parcels in the SERVE catalog")
	assert_false(ShiftScript.PRODUCTS[PARCEL]["prep"], "parcels are instant, no prep")
	assert_true(ProcureScript.CATALOG.has(PARCEL), "parcels in the PROCURE catalog")
	# Margin: wholesale strictly below retail, like every other product.
	assert_true(int(ProcureScript.CATALOG[PARCEL]["cost"]) < int(ShiftScript.PRODUCTS[PARCEL]["price"]),
		"parcel wholesale < retail")


func test_parcels_can_be_procured() -> void:
	var state := StateStub.new()
	state.money = 50
	var procure = ProcureScript.new(state)
	var bought: int = procure.buy(PARCEL, 3)
	assert_eq(bought, 3, "bought the full quantity")
	assert_eq(state.money, 50 - 3 * int(ProcureScript.CATALOG[PARCEL]["cost"]), "money -= wholesale cost")
	assert_eq(int(state.stock.get(PARCEL, 0)), 3, "parcel stock laid in")


func test_parcel_serves_as_instant_grab_and_ring() -> void:
	var state := StateStub.new()
	state.stock = {PARCEL: 2}
	var shift = ShiftScript.new(state)
	shift.auto_spawn = false
	shift.queue = [ShiftScript.Customer.new(PARCEL, 10.0)]
	# No prep step needed — it rings up immediately.
	var ok: bool = shift.serve(PARCEL)
	assert_true(ok, "instant parcel sale succeeded with no prep")
	assert_eq(state.money, ShiftScript.PRODUCTS[PARCEL]["price"], "money += parcel price")
	assert_eq(int(state.stock[PARCEL]), 1, "parcel stock -= 1")
	assert_eq(shift.served_count, 1, "served counted")


func test_parcel_stockout_is_a_lost_sale_never_negative() -> void:
	var state := StateStub.new()
	state.stock = {PARCEL: 0}
	var shift = ShiftScript.new(state)
	shift.auto_spawn = false
	shift.queue = [ShiftScript.Customer.new(PARCEL, 10.0)]
	var ok: bool = shift.serve(PARCEL)
	assert_false(ok, "no sale on a parcel stockout")
	assert_eq(int(state.stock[PARCEL]), 0, "parcel stock never went negative")
	assert_eq(state.money, 0, "no money for a stockout")
	assert_eq(shift.lost_sales, 1, "registered a lost sale")


func test_a_parcel_customer_arrives_when_unlocked() -> void:
	# With parcels available (default catalog), the deterministic rotation cycles through
	# every product, so a full wave eventually wants a parcel — proving parcels are live
	# in the shift, not just serveable when hand-placed.
	var state := StateStub.new()
	state.stock = {"cigarettes": 99, "soda": 99, "hotdog": 99, PARCEL: 99}
	var shift = ShiftScript.new(state)  # _init defaults available_products to the full catalog
	shift.wave_size = ShiftScript.PRODUCTS.size()  # one full lap of the rotation
	shift.spawn_interval = 0.0
	shift.start()
	for i in range(shift.wave_size):
		shift.tick(0.0)
	var wants_parcel := false
	for c in shift.queue:
		if c.product_id == PARCEL:
			wants_parcel = true
	assert_true(wants_parcel, "a parcel-wanting customer appeared in the wave")


func test_parcels_locked_until_the_rating_earns_them() -> void:
	# Forwarders want traction: parcels are out of the unlocked set below 4.0★ and
	# appear once the (sticky best) rating reaches the threshold.
	var below := ShiftScript.unlocked_product_ids(3.9)
	assert_false(below.has(PARCEL), "parcels locked below 4.0★")
	assert_true(below.has("cigarettes"), "ungated staples are always available")
	var at := ShiftScript.unlocked_product_ids(4.0)
	assert_true(at.has(PARCEL), "parcels unlock at 4.0★")


func test_locked_parcels_never_arrive_in_a_shift() -> void:
	# An unrated store excludes parcels from available_products, so no parcel customer
	# ever spawns — even across two full laps of the rotation.
	var state := StateStub.new()
	state.stock = {"cigarettes": 99, "soda": 99, "hotdog": 99, "coffee": 99}
	var shift = ShiftScript.new(state)
	shift.available_products = ShiftScript.unlocked_product_ids(0.0)  # unrated -> no parcels
	shift.wave_size = ShiftScript.PRODUCTS.size() * 2
	shift.spawn_interval = 0.0
	shift.start()
	for i in range(shift.wave_size):
		shift.tick(0.0)
	for c in shift.queue:
		assert_true(c.product_id != PARCEL, "no parcel customer arrives while locked")


func test_crossing_4_stars_newly_unlocks_parcels() -> void:
	# The one-shot unlock celebration keys off this: a shift that lifts best_rating from
	# below the gate to at-or-above it reports the parcel line as newly unlocked.
	var crossed := ShiftScript.newly_unlocked_product_ids(3.9, 4.0)
	assert_true(crossed.has(PARCEL), "parcels are newly unlocked when the rating crosses 4.0★")


func test_no_unlock_when_the_gate_was_already_cleared() -> void:
	# Sticky gate: once you're past 4.0★, climbing further re-celebrates nothing — the
	# parcel line isn't "newly" unlocked a second time.
	var crossed := ShiftScript.newly_unlocked_product_ids(4.2, 4.6)
	assert_true(crossed.is_empty(), "no re-unlock once the gate is already cleared")


func test_no_unlock_when_the_rating_stays_below_the_gate() -> void:
	# A good-but-not-great climb that never reaches 4.0★ unlocks nothing.
	var crossed := ShiftScript.newly_unlocked_product_ids(2.0, 3.8)
	assert_true(crossed.is_empty(), "no unlock while the rating stays under the gate")


func test_parcels_carry_unlock_celebration_copy() -> void:
	# The gated line supplies its own celebration blurb so Main's banner is data-driven.
	assert_true(ShiftScript.PRODUCTS[PARCEL].has("unlock_blurb"), "parcels have unlock_blurb copy")
	assert_true(String(ShiftScript.PRODUCTS[PARCEL]["unlock_blurb"]).length() > 0, "blurb is non-empty")


func test_parcel_stock_survives_save_round_trip() -> void:
	var gs = GameStateScript.new()
	gs.stock[PARCEL] = 7
	var restored = GameStateScript.new()
	restored.from_dict(gs.to_dict())
	assert_eq(int(restored.stock.get(PARCEL, 0)), 7, "parcel stock carried across to_dict/from_dict")
