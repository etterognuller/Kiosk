extends "res://tests/test_case.gd"
## Unit tests for the UPGRADE shop logic (scripts/phases/upgrade_shop.gd). These
## run headless, without the autoload graph: money and owned levels go through a
## tiny GameState-shaped stub, so pricing, affordability and the no-fail invariant
## are exercised in isolation. The cross-seam test additionally drives a *real*
## GameState through a to_dict/from_dict round-trip to prove a bought upgrade
## survives a save and still tunes the next Shift.

const UpgradeShopScript := preload("res://scripts/phases/upgrade_shop.gd")
const ShiftScript := preload("res://scripts/phases/shift.gd")
const GameStateScript := preload("res://scripts/globals/game_state.gd")


## A minimal stand-in for GameState: just the fields UpgradeShop reads/writes.
class StateStub extends RefCounted:
	var money: int = 0
	var upgrades: Dictionary = {}


func _shop(money: int, upgrades: Dictionary = {}) -> Array:
	# Returns [shop, state] with the given purse and owned levels.
	var state := StateStub.new()
	state.money = money
	state.upgrades = upgrades
	var shop = UpgradeShopScript.new(state)
	return [shop, state]


func test_buy_raises_level_and_spends_money() -> void:
	var pair := _shop(50)
	var shop = pair[0]
	var state = pair[1]
	var ok: bool = shop.buy("counter_space")
	assert_true(ok, "purchase succeeded")
	assert_eq(state.money, 20, "money -= base cost (50 - 30)")
	assert_eq(shop.level_of("counter_space"), 1, "owned level rose to 1")


func test_cannot_buy_when_unaffordable() -> void:
	var pair := _shop(10)
	var shop = pair[0]
	var state = pair[1]
	var ok: bool = shop.buy("counter_space")
	assert_false(ok, "no purchase when too dear")
	assert_eq(state.money, 10, "money unchanged")
	assert_eq(shop.level_of("counter_space"), 0, "level unchanged")


func test_buy_never_drives_money_negative() -> void:
	# 30 + 50 = 80 affordable; the next level (70) is over budget and a no-op.
	var pair := _shop(80)
	var shop = pair[0]
	var state = pair[1]
	assert_true(shop.buy("counter_space"), "first level (30)")
	assert_true(shop.buy("counter_space"), "second level (50)")
	assert_eq(state.money, 0, "spent exactly down to zero")
	assert_false(shop.buy("counter_space"), "third level (70) unaffordable")
	assert_eq(state.money, 0, "money never went negative")
	assert_eq(shop.level_of("counter_space"), 2, "level held at 2")


func test_cost_scales_with_level() -> void:
	var pair := _shop(999)
	var shop = pair[0]
	assert_eq(shop.cost_of("counter_space"), 30, "level 0 -> base 30")
	shop.buy("counter_space")
	assert_eq(shop.cost_of("counter_space"), 50, "level 1 -> 30 + 20")
	shop.buy("counter_space")
	assert_eq(shop.cost_of("counter_space"), 70, "level 2 -> 30 + 40")


func test_cannot_exceed_max_level() -> void:
	var pair := _shop(99999)
	var shop = pair[0]
	for i in range(5):
		assert_true(shop.buy("counter_space"), "level %d bought" % (i + 1))
	assert_eq(shop.level_of("counter_space"), 5, "reached max_level 5")
	assert_true(shop.is_maxed("counter_space"), "is_maxed at the cap")
	assert_false(shop.buy("counter_space"), "no purchase past max")
	assert_eq(shop.level_of("counter_space"), 5, "level held at the cap")


func test_unknown_upgrade_is_a_harmless_noop() -> void:
	var pair := _shop(999)
	var shop = pair[0]
	var state = pair[1]
	assert_false(shop.buy("teleporter"), "unknown id is not a purchase")
	assert_eq(state.money, 999, "money untouched")
	assert_false(shop.can_afford("teleporter"), "unknown id never affordable")


func test_level_of_tolerates_empty_upgrades() -> void:
	var pair := _shop(0, {})
	var shop = pair[0]
	assert_eq(shop.level_of("counter_space"), 0, "missing key reads as 0")
	assert_eq(shop.level_of("loyalty_cards"), 0, "missing key reads as 0")


func test_effect_of_maps_level_to_effect() -> void:
	var pair := _shop(0)
	var shop = pair[0]
	assert_eq(shop.effect_of("counter_space", 3), 3.0, "3 * 1.0")
	assert_eq(shop.effect_of("loyalty_cards", 2), 3.0, "2 * 1.5")


func test_apply_to_shift_offsets_from_defaults() -> void:
	var pair := _shop(0, {"counter_space": 2, "loyalty_cards": 1})
	var shop = pair[0]
	var state = pair[1]
	var shift = ShiftScript.new(state)
	shop.apply_to_shift(shift)
	assert_eq(shift.wave_size, ShiftScript.DEFAULT_WAVE_SIZE + 2, "wave_size += 2 customers")
	assert_eq(shift.patience, ShiftScript.DEFAULT_PATIENCE + 1.5, "patience += 1.5s")


func test_cross_seam_round_trip_through_game_state() -> void:
	# The key test: a purchase made against a real GameState must survive a
	# to_dict/from_dict save and still tune the next Shift. Top the purse up so
	# all three buys land — affordability is covered elsewhere; this is about
	# serialization carrying owned levels across the seam.
	var gs = GameStateScript.new()
	gs.money = 999
	var shop = UpgradeShopScript.new(gs)
	assert_true(shop.buy("counter_space"), "counter_space level 1")
	assert_true(shop.buy("counter_space"), "counter_space level 2")
	assert_true(shop.buy("loyalty_cards"), "loyalty_cards level 1")
	var snapshot: Dictionary = gs.to_dict()

	var restored = GameStateScript.new()
	restored.from_dict(snapshot)
	var shift = ShiftScript.new(restored)
	UpgradeShopScript.new(restored).apply_to_shift(shift)
	assert_eq(shift.wave_size, ShiftScript.DEFAULT_WAVE_SIZE + 2, "counter_space x2 survived the save")
	assert_eq(shift.patience, ShiftScript.DEFAULT_PATIENCE + 1.5, "loyalty_cards x1 survived the save")


func test_requirement_of_reports_the_tree_edge() -> void:
	# second_counter is gated behind counter_space Lv 2; the others are roots.
	var pair := _shop(0)
	var shop = pair[0]
	assert_eq(shop.requirement_of("second_counter"), {"id": "counter_space", "level": 2}, "gated edge reported")
	assert_true(shop.requirement_of("counter_space").is_empty(), "root upgrade has no prerequisite")
	assert_true(shop.requirement_of("teleporter").is_empty(), "unknown id has no prerequisite")


func test_gated_upgrade_is_locked_until_prerequisite_met() -> void:
	# Plenty of money, but the prerequisite (counter_space Lv 2) is unmet.
	var pair := _shop(9999, {"counter_space": 1})
	var shop = pair[0]
	assert_false(shop.is_unlocked("second_counter"), "locked at counter_space Lv 1")
	assert_false(shop.can_buy("second_counter"), "cannot buy while locked, even with money")
	# Reaching the prerequisite level unlocks it.
	shop.buy("counter_space")  # -> Lv 2
	assert_true(shop.is_unlocked("second_counter"), "unlocked once counter_space hits Lv 2")
	assert_true(shop.can_buy("second_counter"), "buyable once unlocked and affordable")


func test_buying_a_locked_upgrade_is_a_harmless_noop() -> void:
	# No-fail invariant: pressing Buy on a locked row spends nothing and crashes nothing.
	var pair := _shop(9999, {"counter_space": 0})
	var shop = pair[0]
	var state = pair[1]
	assert_false(shop.buy("second_counter"), "locked buy is not a purchase")
	assert_eq(state.money, 9999, "money untouched while locked")
	assert_eq(shop.level_of("second_counter"), 0, "level stays at 0 while locked")


func test_unlocked_gated_upgrade_buys_like_any_other() -> void:
	# Once the gate is open it follows the normal cost-scaling / max-level rules.
	var pair := _shop(9999, {"counter_space": 2})
	var shop = pair[0]
	assert_eq(shop.cost_of("second_counter"), 120, "level 0 -> base 120")
	assert_true(shop.buy("second_counter"), "first level bought")
	assert_eq(shop.cost_of("second_counter"), 200, "level 1 -> 120 + 80")
	assert_true(shop.buy("second_counter"), "second level")
	assert_true(shop.buy("second_counter"), "third level")
	assert_true(shop.is_maxed("second_counter"), "maxed at level 3")
	assert_false(shop.buy("second_counter"), "no purchase past max")


func test_second_counter_stacks_on_wave_size_once_owned() -> void:
	# Proves the effect flows end-to-end: counter_space (+1/lvl) and second_counter
	# (+2/lvl) both raise wave_size, summed in apply_to_shift.
	var pair := _shop(0, {"counter_space": 2, "second_counter": 1})
	var shop = pair[0]
	var state = pair[1]
	var shift = ShiftScript.new(state)
	shop.apply_to_shift(shift)
	assert_eq(shift.wave_size, ShiftScript.DEFAULT_WAVE_SIZE + 2 + 2, "counter_space x2 (+2) and second_counter x1 (+2)")


func test_gated_upgrade_level_survives_round_trip() -> void:
	# Owned level of the new upgrade must persist across a save/load, and the
	# prerequisite link must still resolve as unlocked afterwards.
	var gs = GameStateScript.new()
	gs.money = 9999
	var shop = UpgradeShopScript.new(gs)
	shop.buy("counter_space")  # Lv 1
	shop.buy("counter_space")  # Lv 2 -> unlocks second_counter
	assert_true(shop.buy("second_counter"), "second_counter Lv 1")
	var snapshot: Dictionary = gs.to_dict()

	var restored = GameStateScript.new()
	restored.from_dict(snapshot)
	var restored_shop = UpgradeShopScript.new(restored)
	assert_eq(restored_shop.level_of("second_counter"), 1, "owned level survived the save")
	assert_true(restored_shop.is_unlocked("second_counter"), "still unlocked after load")


func test_day1_starter_upgrades_are_affordable() -> void:
	# Smoke: on a fresh state (50 kr) the first level of either upgrade is buyable.
	var pair := _shop(GameStateScript.STARTING_MONEY)
	var shop = pair[0]
	assert_true(shop.cost_of("loyalty_cards") <= GameStateScript.STARTING_MONEY, "loyalty_cards (25) affordable day 1")
	assert_true(shop.cost_of("counter_space") <= GameStateScript.STARTING_MONEY, "counter_space (30) affordable day 1")
