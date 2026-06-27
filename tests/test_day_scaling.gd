extends "res://tests/test_case.gd"
## Unit tests for day-driven escalation (scripts/day_scaling.gd) and how it
## composes with the upgrade tuning. The bonus math is pure; the composition test
## drives a real GameState + UpgradeShop + Shift to prove serve.gd's recipe
## (upgrade bonuses, then the day bonus on top) lands the right final wave size.

const DayScalingScript := preload("res://scripts/day_scaling.gd")
const UpgradeShopScript := preload("res://scripts/phases/upgrade_shop.gd")
const ShiftScript := preload("res://scripts/phases/shift.gd")
const GameStateScript := preload("res://scripts/globals/game_state.gd")


func test_day_one_adds_no_bonus() -> void:
	# Day 1 keeps the tuned opening shift intact.
	assert_eq(DayScalingScript.wave_bonus(1), 0, "day 1 -> +0")


func test_bonus_increases_with_the_day() -> void:
	assert_eq(DayScalingScript.wave_bonus(2), 1, "day 2 -> +1")
	assert_eq(DayScalingScript.wave_bonus(3), 2, "day 3 -> +2")
	assert_true(DayScalingScript.wave_bonus(5) > DayScalingScript.wave_bonus(3), "later day is busier")


func test_bonus_is_bounded_by_the_cap() -> void:
	var cap := DayScalingScript.MAX_WAVE_BONUS
	assert_eq(DayScalingScript.wave_bonus(1 + cap), cap, "reaches the cap")
	assert_eq(DayScalingScript.wave_bonus(999), cap, "far-future day stays at the cap, never an unwinnable wall")


func test_bonus_never_negative_for_degenerate_days() -> void:
	# A day counter at or below 1 (or a bad value) must never shrink the wave.
	assert_eq(DayScalingScript.wave_bonus(0), 0, "day 0 -> +0")
	assert_eq(DayScalingScript.wave_bonus(-3), 0, "negative day -> +0")


func test_composes_with_upgrade_tuning() -> void:
	# serve.gd's recipe: apply_to_shift (DEFAULT + upgrade bonus), then += day bonus.
	# counter_space x2 (+2) at day 4 (+3) -> DEFAULT + 2 + 3.
	var gs = GameStateScript.new()
	gs.upgrades = {"counter_space": 2, "second_counter": 0, "loyalty_cards": 0, "clerk": 0}
	gs.day = 4
	var shift = ShiftScript.new(gs)
	UpgradeShopScript.new(gs).apply_to_shift(shift)
	shift.wave_size += DayScalingScript.wave_bonus(gs.day)
	assert_eq(shift.wave_size, ShiftScript.DEFAULT_WAVE_SIZE + 2 + 3, "upgrade and day bonuses compose additively")


func test_day_scaling_only_grows_the_wave() -> void:
	# Sanity across a run of days: the wave is monotonic non-decreasing and always
	# at least the default — escalation never produces a smaller-than-day-1 shift.
	var prev := ShiftScript.DEFAULT_WAVE_SIZE
	for day in range(1, 12):
		var wave := ShiftScript.DEFAULT_WAVE_SIZE + DayScalingScript.wave_bonus(day)
		assert_true(wave >= prev, "day %d wave (%d) >= previous (%d)" % [day, wave, prev])
		prev = wave
