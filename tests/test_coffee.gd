extends "res://tests/test_case.gd"
## Unit tests for the second product tier (issue #5) — coffee, a higher-value
## light-prep signature item that reuses the hot dog's prep path. These pin the
## new wiring: coffee is procurable at a margin, cannot be served before its prep
## steps complete, rings up money/stock when handed over, a stockout is a no-fail
## lost sale, the auto-serve clerk preps then serves it, and stock round-trips.

const ProcureScript := preload("res://scripts/phases/procure.gd")
const ShiftScript := preload("res://scripts/phases/shift.gd")
const ServeDriverScript := preload("res://scripts/phases/serve_driver.gd")
const GameStateScript := preload("res://scripts/globals/game_state.gd")

const COFFEE := "coffee"


class StateStub extends RefCounted:
	var money: int = 0
	var stock: Dictionary = {}


func _shift(stock: Dictionary) -> Array:
	var state := StateStub.new()
	state.stock = stock
	var shift = ShiftScript.new(state)
	shift.auto_spawn = false
	return [shift, state]


func test_coffee_is_a_higher_value_prep_item_in_both_catalogs() -> void:
	assert_true(ShiftScript.PRODUCTS.has(COFFEE), "coffee in the SERVE catalog")
	assert_true(ShiftScript.PRODUCTS[COFFEE]["prep"], "coffee is a light-prep item")
	assert_true(ProcureScript.CATALOG.has(COFFEE), "coffee in the PROCURE catalog")
	# Higher-value: priced above the hot dog (the previous top item).
	assert_true(int(ShiftScript.PRODUCTS[COFFEE]["price"]) > int(ShiftScript.PRODUCTS["hotdog"]["price"]),
		"coffee retail above the hot dog")
	assert_true(int(ProcureScript.CATALOG[COFFEE]["cost"]) < int(ShiftScript.PRODUCTS[COFFEE]["price"]),
		"coffee wholesale < retail (a margin)")


func test_coffee_can_be_procured() -> void:
	var state := StateStub.new()
	state.money = 60
	var procure = ProcureScript.new(state)
	var bought: int = procure.buy(COFFEE, 2)
	assert_eq(bought, 2, "bought the full quantity")
	assert_eq(state.money, 60 - 2 * int(ProcureScript.CATALOG[COFFEE]["cost"]), "money -= wholesale cost")
	assert_eq(int(state.stock.get(COFFEE, 0)), 2, "coffee stock laid in")


func test_coffee_cannot_be_served_before_prep_completes() -> void:
	var pair := _shift({COFFEE: 1})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new(COFFEE, 30.0)]
	assert_false(shift.serve(COFFEE), "cannot serve un-prepped coffee")
	assert_eq(int(state.stock[COFFEE]), 1, "stock untouched before prep")
	for i in range(ShiftScript.PREP_STEPS):
		assert_true(shift.prep_step(), "prep step %d" % (i + 1))
	assert_false(shift.prep_step(), "no prep beyond PREP_STEPS")
	assert_true(shift.serve(COFFEE), "hands over once fully prepped")
	assert_eq(int(state.stock[COFFEE]), 0, "stock consumed on the sale")
	assert_eq(state.money, ShiftScript.PRODUCTS[COFFEE]["price"], "money += coffee price")
	assert_eq(shift.served_count, 1, "served counted")


func test_coffee_stockout_is_a_lost_sale_never_negative() -> void:
	# Prep completes, but there's no coffee to hand over -> a no-fail lost sale.
	var pair := _shift({COFFEE: 0})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new(COFFEE, 30.0)]
	for _i in range(ShiftScript.PREP_STEPS):
		shift.prep_step()
	assert_false(shift.serve(COFFEE), "no sale on a coffee stockout")
	assert_eq(int(state.stock[COFFEE]), 0, "stock never went negative")
	assert_eq(state.money, 0, "no money for a stockout")
	assert_eq(shift.lost_sales, 1, "registered a lost sale")


func test_clerk_preps_then_serves_coffee() -> void:
	# The auto-serve clerk handles coffee with the same generic prep path as the
	# hot dog: PREP_STEPS prep beats, then a hand-over beat.
	var pair := _shift({COFFEE: 1})
	var shift = pair[0]
	var state = pair[1]
	shift.queue = [ShiftScript.Customer.new(COFFEE, 999.0)]
	var driver = ServeDriverScript.new(shift, 1)  # cadence 3.0
	for i in range(ShiftScript.PREP_STEPS):
		assert_true(driver.tick(3.0), "prep beat %d acted" % (i + 1))
		assert_eq(shift.served_count, 0, "not served during prep")
	assert_true(driver.tick(3.0), "hand-over beat acted")
	assert_eq(shift.served_count, 1, "clerk served coffee after prep")
	assert_eq(int(state.stock[COFFEE]), 0, "stock consumed")
	assert_eq(state.money, ShiftScript.PRODUCTS[COFFEE]["price"], "money += coffee price")


func test_coffee_stock_survives_save_round_trip() -> void:
	var gs = GameStateScript.new()
	gs.stock[COFFEE] = 4
	var restored = GameStateScript.new()
	restored.from_dict(gs.to_dict())
	assert_eq(int(restored.stock.get(COFFEE, 0)), 4, "coffee stock carried across to_dict/from_dict")
