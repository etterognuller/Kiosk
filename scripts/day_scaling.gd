extends RefCounted
## DayScaling — pure logic for day-driven shift escalation (issue #2).
##
## "Multiple days = progression": later days bring busier shifts. This maps the
## current day number to a gentle, *bounded* bonus added to the shift's wave size,
## so day 5 is meatier than day 1 while staying readable and no-fail (CONTEXT.md:
## cozy — a busier day means more customers and more income, never an unwinnable
## wall). A bigger wave lengthens the shift rather than tightening per-customer
## timing, so the active option (manual play + the auto-serve clerk) stays
## meaningful as days scale (invariant 4).
##
## Composes additively with the upgrade tuning: serve.gd applies the upgrade
## bonuses (UpgradeShop.apply_to_shift) first, then adds this day bonus on top.
## Pure and clock-free — the day is passed in — so it unit-tests in isolation.
## All functions are static; there is no state to hold.

## Placeholder tuning (CONTEXT.md defers numbers) — flagged for a feel pass.
## +1 customer per day past the first, capped so the ramp plateaus into a gentle,
## bounded busier-but-not-brutal shift (upgrades carry growth beyond the cap).
const WAVE_BONUS_PER_DAY := 1
const MAX_WAVE_BONUS := 6


## Extra customers added to the wave on `day`. Day 1 adds nothing (keeps the tuned
## v1 opening shift intact); each later day adds WAVE_BONUS_PER_DAY, clamped to
## MAX_WAVE_BONUS. Never negative — a day at or below 1 yields 0.
static func wave_bonus(day: int) -> int:
	var days_past_first: int = day - 1
	if days_past_first <= 0:
		return 0
	return mini(days_past_first * WAVE_BONUS_PER_DAY, MAX_WAVE_BONUS)
