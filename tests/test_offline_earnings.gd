extends "res://tests/test_case.gd"
## Unit tests for the days-away catch-up logic (scripts/offline_earnings.gd).
## Pure math, no autoloads or system clock: each test passes an explicit
## (last_saved_unix, now_unix) pair. Covers the day count, the cap, and every
## no-fail edge — missing timestamp, sub-day gap, and a backwards clock.

const OfflineEarningsScript := preload("res://scripts/offline_earnings.gd")

const DAY := 86400


func test_days_away_floors_whole_days() -> void:
	# 2.5 days of seconds -> 2 whole days.
	var now := 10_000_000
	assert_eq(OfflineEarningsScript.days_away(now - (DAY * 2 + DAY / 2), now), 2, "2.5 days floors to 2")
	assert_eq(OfflineEarningsScript.days_away(now - DAY * 3, now), 3, "exactly 3 days")


func test_sub_day_gap_is_zero_days() -> void:
	var now := 10_000_000
	assert_eq(OfflineEarningsScript.days_away(now - (DAY - 1), now), 0, "just under a day -> 0")
	assert_eq(OfflineEarningsScript.days_away(now, now), 0, "no gap -> 0")


func test_missing_timestamp_is_zero() -> void:
	# A never-saved fresh game has last_saved_unix 0.
	assert_eq(OfflineEarningsScript.days_away(0, 10_000_000), 0, "no prior save -> 0 days")


func test_backwards_clock_is_safe() -> void:
	# now earlier than the save (clock moved back) must not go negative.
	assert_eq(OfflineEarningsScript.days_away(10_000_000, 9_000_000), 0, "negative gap -> 0 days")


func test_reward_is_proportional_to_days() -> void:
	assert_eq(OfflineEarningsScript.reward_for(0), 0, "0 days pays nothing")
	assert_eq(OfflineEarningsScript.reward_for(1), OfflineEarningsScript.KR_PER_DAY, "1 day -> per-day rate")
	assert_eq(OfflineEarningsScript.reward_for(3), 3 * OfflineEarningsScript.KR_PER_DAY, "3 days -> 3x rate")


func test_reward_is_capped_at_max_days() -> void:
	var cap := OfflineEarningsScript.MAX_DAYS
	var capped := cap * OfflineEarningsScript.KR_PER_DAY
	assert_eq(OfflineEarningsScript.reward_for(cap), capped, "exactly at the cap")
	assert_eq(OfflineEarningsScript.reward_for(cap + 50), capped, "far past the cap still pays the cap")


func test_reward_never_negative() -> void:
	assert_eq(OfflineEarningsScript.reward_for(-5), 0, "negative days never pay out")


func test_compute_returns_days_and_capped_reward() -> void:
	var now := 10_000_000
	# 10 days away, but reward is capped at MAX_DAYS — the message still shows the
	# true days while the payout is bounded.
	var report: Dictionary = OfflineEarningsScript.compute(now - DAY * 10, now)
	assert_eq(report["days"], 10, "true days away reported")
	assert_eq(report["reward"], OfflineEarningsScript.MAX_DAYS * OfflineEarningsScript.KR_PER_DAY, "reward capped")


func test_compute_fresh_game_grants_nothing() -> void:
	var report: Dictionary = OfflineEarningsScript.compute(0, 10_000_000)
	assert_eq(report["days"], 0, "no days on a fresh game")
	assert_eq(report["reward"], 0, "no reward on a fresh game")
