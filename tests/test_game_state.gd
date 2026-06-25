extends "res://tests/test_case.gd"
## Smoke tests for GameState — exercises the data model in isolation (no autoload,
## no file I/O so the player's real save is never touched).

const GameStateScript := preload("res://scripts/globals/game_state.gd")


func test_to_from_dict_round_trip() -> void:
	var gs = GameStateScript.new()
	gs.money = 123
	gs.day = 7
	gs.stock = {"cigarettes": 4, "soda": 2, "hotdog": 1}
	var snapshot: Dictionary = gs.to_dict()

	var restored = GameStateScript.new()
	restored.from_dict(snapshot)
	assert_eq(restored.money, 123, "money")
	assert_eq(restored.day, 7, "day")
	assert_eq(int(restored.stock["soda"]), 2, "stock.soda")


func test_to_dict_includes_upgrades() -> void:
	var gs = GameStateScript.new()
	var snapshot: Dictionary = gs.to_dict()
	assert_true(snapshot.has("upgrades"), "to_dict exposes upgrades")


func test_upgrades_round_trip() -> void:
	var gs = GameStateScript.new()
	gs.upgrades = {"counter_space": 2, "loyalty_cards": 1}
	var snapshot: Dictionary = gs.to_dict()

	var restored = GameStateScript.new()
	restored.from_dict(snapshot)
	assert_eq(int(restored.upgrades["counter_space"]), 2, "upgrades.counter_space")
	assert_eq(int(restored.upgrades["loyalty_cards"]), 1, "upgrades.loyalty_cards")


func test_from_dict_tolerates_missing_upgrades() -> void:
	# Old saves predating the UPGRADE phase lack the key; the default survives.
	var gs = GameStateScript.new()
	gs.from_dict({"day": 3})
	assert_eq(gs.day, 3, "day taken from dict")
	assert_eq(int(gs.upgrades["counter_space"]), 0, "upgrades default kept when absent")


func test_reset_returns_to_defaults() -> void:
	var gs = GameStateScript.new()
	gs.money = 9999
	gs.day = 50
	gs.upgrades = {"counter_space": 5, "loyalty_cards": 3}
	gs.reset()
	assert_eq(gs.day, 1, "day resets to 1")
	assert_eq(gs.money, GameStateScript.STARTING_MONEY, "money resets to starting value")
	assert_eq(int(gs.upgrades["counter_space"]), 0, "upgrades reset to defaults")


func test_from_dict_tolerates_missing_keys() -> void:
	# Forward/backward-compatible loads: unknown/missing keys keep current values.
	var gs = GameStateScript.new()
	gs.money = 40
	gs.from_dict({"day": 3})
	assert_eq(gs.day, 3, "day taken from dict")
	assert_eq(gs.money, 40, "money unchanged when absent from dict")
