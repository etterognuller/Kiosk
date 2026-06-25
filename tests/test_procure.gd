extends "res://tests/test_case.gd"
## Unit tests for the PROCURE buying logic (scripts/phases/procure.gd). These run
## headless, without the autoload graph: money/stock go through a tiny
## GameState-shaped stub, mirroring test_shift.gd. They lock in the no-fail
## invariant (money/stock never negative, unaffordable buys are no-ops) and guard
## against price drift between wholesale (CATALOG) and retail (shift.gd PRODUCTS).

const ProcureScript := preload("res://scripts/phases/procure.gd")
const ShiftScript := preload("res://scripts/phases/shift.gd")


## A minimal stand-in for GameState: just the fields Procure reads/writes.
class StateStub extends RefCounted:
	var money: int = 0
	var stock: Dictionary = {}


func _with(money: int) -> Array:
	# Returns [procure, state] with the given balance and empty stock.
	var state := StateStub.new()
	state.money = money
	var procure = ProcureScript.new(state)
	return [procure, state]


func test_buy_spends_money_and_adds_stock() -> void:
	var pair := _with(50)
	var procure = pair[0]
	var state = pair[1]
	var bought: int = procure.buy("cigarettes", 3)
	assert_eq(bought, 3, "bought the full quantity")
	assert_eq(state.money, 50 - 3 * 3, "money -= cost (3 @ 3 kr)")
	assert_eq(int(state.stock.get("cigarettes", 0)), 3, "stock += quantity")


func test_over_budget_buy_clamps_and_never_goes_negative() -> void:
	# money 8, cigarettes @ 3 kr -> can afford 2, asked for 5.
	var pair := _with(8)
	var procure = pair[0]
	var state = pair[1]
	var bought: int = procure.buy("cigarettes", 5)
	assert_eq(bought, 2, "clamped to what the wallet allows")
	assert_eq(state.money, 2, "spent only on the clamped amount")
	assert_true(state.money >= 0, "money never goes negative")
	assert_eq(int(state.stock.get("cigarettes", 0)), 2, "got the clamped units")


func test_buy_at_zero_money_is_a_noop() -> void:
	var pair := _with(0)
	var procure = pair[0]
	var state = pair[1]
	var bought: int = procure.buy("cigarettes", 5)
	assert_eq(bought, 0, "nothing bought with an empty purse")
	assert_eq(state.money, 0, "money untouched")
	assert_eq(int(state.stock.get("cigarettes", 0)), 0, "stock untouched")


func test_zero_negative_and_unknown_buys_are_noops() -> void:
	var pair := _with(50)
	var procure = pair[0]
	var state = pair[1]
	assert_eq(procure.buy("soda", 0), 0, "qty 0 buys nothing")
	assert_eq(procure.buy("soda", -3), 0, "negative qty buys nothing")
	assert_eq(procure.buy("teleporter", 5), 0, "unknown id buys nothing")
	assert_eq(state.money, 50, "money untouched by every no-op")
	assert_eq(int(state.stock.get("teleporter", 0)), 0, "no stray stock key created")


func test_catalog_cost_is_below_sell_price_for_every_product() -> void:
	# Drift guard: every wholesale cost must stay strictly under its retail price,
	# so each unit sold in SERVE turns a margin.
	for id in ProcureScript.CATALOG:
		var cost := int(ProcureScript.CATALOG[id]["cost"])
		var price := int(ShiftScript.PRODUCTS[id]["price"])
		assert_true(cost < price, "%s cost %d < sell price %d" % [id, cost, price])


func test_day_one_budget_buys_a_runnable_shift() -> void:
	# Starting money should stock enough for a playable opening shift.
	var pair := _with(50)
	var procure = pair[0]
	var state = pair[1]
	procure.buy("cigarettes", 4)
	procure.buy("soda", 4)
	procure.buy("hotdog", 2)
	assert_true(state.money >= 0, "still solvent after stocking up")
	var spent: int = 50 - state.money
	assert_true(spent <= 50, "spent within the day-1 budget")
	assert_true(procure.total_units() >= 8, "laid in a runnable amount of stock")


func test_max_affordable_tracks_money_and_is_zero_when_broke() -> void:
	var pair := _with(7)
	var procure = pair[0]
	# cigarettes @ 3 kr -> 7 / 3 == 2.
	assert_eq(procure.max_affordable("cigarettes"), 2, "integer-div of money by cost")
	assert_true(procure.can_afford("cigarettes", 2), "can afford the full amount")
	assert_false(procure.can_afford("cigarettes", 3), "can't afford beyond budget")
	var broke := _with(0)
	assert_eq(broke[0].max_affordable("cigarettes"), 0, "0 affordable when broke")


func test_stock_changed_fires_on_a_real_buy_but_not_on_a_clamped_noop() -> void:
	var pair := _with(0)
	var procure = pair[0]
	var fired := [0]
	procure.stock_changed.connect(func(): fired[0] += 1)
	assert_eq(procure.buy("cigarettes", 5), 0, "broke buy is a no-op")
	assert_eq(fired[0], 0, "no signal for a clamped no-op")
	procure._state.money = 50
	assert_eq(procure.buy("cigarettes", 1), 1, "now a real buy")
	assert_eq(fired[0], 1, "stock_changed fired exactly once on the real buy")
