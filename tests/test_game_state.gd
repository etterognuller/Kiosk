extends "res://tests/test_case.gd"
## Smoke tests for GameState — exercises the data model in isolation (no autoload,
## no file I/O so the player's real save is never touched).

const GameStateScript := preload("res://scripts/globals/game_state.gd")


func test_to_from_dict_round_trip() -> void:
	var gs = GameStateScript.new()
	gs.money = 123
	gs.review_points = 41
	gs.review_count = 9
	gs.best_rating = 4.5
	gs.day = 7
	gs.stock = {"cigarettes": 4, "soda": 2, "hotdog": 1}
	var snapshot: Dictionary = gs.to_dict()

	var restored = GameStateScript.new()
	restored.from_dict(snapshot)
	assert_eq(restored.money, 123, "money")
	assert_eq(restored.review_points, 41, "review_points survived the round-trip")
	assert_eq(restored.review_count, 9, "review_count survived the round-trip")
	assert_eq(restored.best_rating, 4.5, "best_rating survived the round-trip")
	assert_eq(restored.day, 7, "day")
	assert_eq(int(restored.stock["soda"]), 2, "stock.soda")


func test_fresh_game_starts_unrated() -> void:
	var gs = GameStateScript.new()
	assert_eq(gs.review_count, 0, "fresh game has no reviews")
	assert_eq(gs.review_points, 0, "fresh game has no review points")


func test_reset_clears_reviews() -> void:
	var gs = GameStateScript.new()
	gs.review_points = 30
	gs.review_count = 7
	gs.best_rating = 4.2
	gs.reset()
	assert_eq(gs.review_count, 0, "reset clears the review count")
	assert_eq(gs.review_points, 0, "reset clears the review points")
	assert_eq(gs.best_rating, 0.0, "reset clears the best rating")


func test_commit_reviews_accumulates_and_tracks_peak() -> void:
	# serve.gd folds a shift's tally in at day's end; best_rating tracks the peak so
	# rating-gated unlocks stay sticky.
	var gs = GameStateScript.new()
	gs.commit_reviews(50, 10)  # a clean opening day: ten 5★ reviews -> ~3.9
	assert_eq(gs.review_points, 50, "points committed")
	assert_eq(gs.review_count, 10, "count committed")
	assert_true(gs.best_rating > 3.8 and gs.best_rating < 4.0, "best_rating ~3.9 after ten 5★ reviews")
	var peak: float = gs.best_rating
	gs.commit_reviews(1, 1)  # a 1★ review drags the live rating below the peak
	assert_eq(gs.review_count, 11, "second batch folded in")
	assert_true(gs.best_rating >= peak, "best_rating never decreases (sticky unlocks)")


func test_from_dict_tolerates_missing_reviews() -> void:
	# Saves predating Reputation v2 lack the review keys; the unrated default survives.
	var gs = GameStateScript.new()
	gs.from_dict({"day": 4})
	assert_eq(gs.day, 4, "day taken from dict")
	assert_eq(gs.review_count, 0, "review_count default kept when absent")
	assert_eq(gs.review_points, 0, "review_points default kept when absent")


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
