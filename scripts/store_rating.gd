extends RefCounted
## StoreRating — pure logic for the store's customer rating (Reputation v2).
##
## The store rating emerges from customer reviews, Trustpilot-style: every resolved
## customer leaves one whole-star review, and the displayed rating is a *Bayesian*
## average of all reviews ever. The store starts Unrated (zero reviews) and the
## rating climbs gradually as good reviews accumulate — so 5★ is "a little way" off
## and, once a store is well-reviewed, one bad day barely moves it.
##
## This is the single place that maps reviews -> a rating -> stars; GameState only
## stores the running totals (review_points, review_count). Pure and static — no
## state, no autoloads, clock-free — so it unit-tests in isolation exactly like
## day_scaling.gd / offline_earnings.gd.
##
## Out of scope here (deferred): the rating has no mechanical effect yet. The systems
## that give it teeth — popularity as a currency, points-for-rating, store upgrades
## bought with popularity, and "more stars -> more customers" — come later.

## Bayesian prior. The rating is (PRIOR_WEIGHT * PRIOR_MEAN + review_points) /
## (PRIOR_WEIGHT + review_count): the store opens with PRIOR_WEIGHT "virtual" reviews
## at PRIOR_MEAN stars that real reviews dilute. PRIOR_MEAN 0 makes a fresh store
## start at the bottom; PRIOR_WEIGHT is the single knob for "how long the way to 5★".
## Tuned so a clean opening day — 10 fast, perfect (5★) serves — lands ~3.9★, not 5
## right away: 50 / (2.8 + 10) = 3.9. Placeholder tuning (CONTEXT.md) — flag for F5.
const PRIOR_WEIGHT := 2.8
const PRIOR_MEAN := 0.0

## Whole-star scores a single review can carry. Served reviews are promptness-scaled
## (faster service = happier customer); a lost sale is the floor. 2★ is unused for now.
## Thresholds are fractions of the customer's remaining patience at serve time.
## Placeholder tuning — flag for an F5 feel pass.
const REVIEW_SERVED_FAST := 5    ## served with lots of patience left
const REVIEW_SERVED_OK := 4      ## served with some patience left
const REVIEW_SERVED_SLOW := 3    ## served at the last second
const REVIEW_LOST := 1           ## stockout or patience timeout
const SERVED_FAST_FRACTION := 0.66
const SERVED_OK_FRACTION := 0.33

const MAX_STARS := 5
const FILLED := "★"
const HALF := "½"
const EMPTY := "☆"


## The review a served customer leaves, by how much patience remained at serve time
## (1.0 = served instantly, 0.0 = served as patience ran out). The clerk's serves
## route through here too, so a slow clerk earns more 3-4★ than a brisk player.
static func review_for_served(patience_fraction: float) -> int:
	var frac := clampf(patience_fraction, 0.0, 1.0)
	if frac >= SERVED_FAST_FRACTION:
		return REVIEW_SERVED_FAST
	if frac >= SERVED_OK_FRACTION:
		return REVIEW_SERVED_OK
	return REVIEW_SERVED_SLOW


## The Bayesian rating in stars (0..MAX_STARS) for the running review totals. An
## unrated store (no reviews) returns PRIOR_MEAN; callers should branch on
## is_unrated() for display rather than showing that number.
static func rating(review_points: int, review_count: int) -> float:
	return (PRIOR_WEIGHT * PRIOR_MEAN + float(review_points)) / (PRIOR_WEIGHT + float(review_count))


## True before the first review lands — the store has no rating to show yet.
static func is_unrated(review_count: int) -> bool:
	return review_count <= 0


## A rating as a fixed-width (MAX_STARS-glyph) row, rounded to the nearest half star:
## e.g. 1.7 -> "★½☆☆☆", 4.5 -> "★★★★½". The exact value is shown separately as a
## decimal; the glyphs are the at-a-glance gestalt.
static func star_string(rating_value: float) -> String:
	var halves := int(round(clampf(rating_value, 0.0, float(MAX_STARS)) * 2.0))  # 0..2*MAX_STARS
	var full := halves / 2
	var has_half := (halves % 2) == 1
	var empty := MAX_STARS - full - (1 if has_half else 0)
	return FILLED.repeat(full) + (HALF if has_half else "") + EMPTY.repeat(empty)


## The full HUD line. "Unrated · no reviews yet" until the first review, then the
## star row + the exact one-decimal rating + the review count (the Trustpilot tell
## that makes early volatility legible). Centralised here so the display is testable.
static func summary(review_points: int, review_count: int) -> String:
	if is_unrated(review_count):
		return "Unrated · no reviews yet"
	var r := rating(review_points, review_count)
	var noun := "review" if review_count == 1 else "reviews"
	return "%s  %.1f  (%d %s)" % [star_string(r), r, review_count, noun]
