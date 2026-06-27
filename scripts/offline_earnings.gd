extends RefCounted
## OfflineEarnings — pure logic for the days-away catch-up reward (issue #6).
##
## When the game loads, the gap between the saved timestamp (last_saved_unix) and
## now is converted into *whole days away* — the day is the unit for offline time
## (CONTEXT.md invariant) — and turned into a cozy, purely-positive reward. Being
## away never costs the player (no-fail), the payout is bounded by a day cap so a
## long absence can't pay out absurdly, and every edge (no save, sub-day gap, a
## clock that moved backwards) yields nothing rather than erroring or going
## negative.
##
## Deliberately free of the autoload graph and the system clock: callers pass
## `now_unix` in, so the math unit-tests in isolation (see tests/). The single
## consumer is the Game autoload, which grants the reward on boot. All functions
## are static — there is no state to hold.

const SECONDS_PER_DAY := 86400

## Placeholder tuning (CONTEXT.md defers numbers) — flagged for a feel pass.
## A flat per-day amount; could later scale by current state (e.g. clerk level).
const KR_PER_DAY := 20
## Cap on paid days so a months-long absence can't dump an absurd payout.
const MAX_DAYS := 7


## Whole days between a save timestamp and now, floored. Never negative: a missing
## timestamp (<= 0, e.g. a never-saved fresh game), a clock that moved backwards
## (gap < 0), or a sub-day gap all return 0.
static func days_away(last_saved_unix: int, now_unix: int) -> int:
	if last_saved_unix <= 0:
		return 0
	var gap: int = now_unix - last_saved_unix
	if gap < 0:
		return 0
	return gap / SECONDS_PER_DAY  # int / int floors in GDScript


## The capped catch-up reward for being away `raw_days`. Proportional to days but
## never more than MAX_DAYS worth; 0 or fewer days pays nothing.
static func reward_for(raw_days: int) -> int:
	var paid_days: int = mini(raw_days, MAX_DAYS)
	if paid_days <= 0:
		return 0
	return paid_days * KR_PER_DAY


## Convenience for the boot path: {days, reward} for a save timestamp vs now.
## `days` is the true days away (for the "N days passed" message); `reward` is the
## capped payout actually granted.
static func compute(last_saved_unix: int, now_unix: int) -> Dictionary:
	var d: int = days_away(last_saved_unix, now_unix)
	return {"days": d, "reward": reward_for(d)}
