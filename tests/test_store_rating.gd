extends "res://tests/test_case.gd"
## Unit tests for the store rating logic (scripts/store_rating.gd). Pure logic, so the
## contract is: promptness maps to the right review score, the Bayesian average starts
## Unrated and climbs gradually (never snapping to 5★ on one review) and is robust once
## established, the star glyph row rounds to the nearest half and stays a fixed width,
## and the HUD summary reads correctly incl. the Unrated state and pluralisation.

const StoreRating := preload("res://scripts/store_rating.gd")


## Float compare helper (assert_eq is exact); not a test_ method, so the runner skips it.
func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func test_review_for_served_bands() -> void:
	assert_eq(StoreRating.review_for_served(1.0), StoreRating.REVIEW_SERVED_FAST, "full patience -> top")
	assert_eq(StoreRating.review_for_served(0.66), StoreRating.REVIEW_SERVED_FAST, "at the fast threshold")
	assert_eq(StoreRating.review_for_served(0.65), StoreRating.REVIEW_SERVED_OK, "just below fast -> ok")
	assert_eq(StoreRating.review_for_served(0.33), StoreRating.REVIEW_SERVED_OK, "at the ok threshold")
	assert_eq(StoreRating.review_for_served(0.32), StoreRating.REVIEW_SERVED_SLOW, "just below ok -> slow")
	assert_eq(StoreRating.review_for_served(0.0), StoreRating.REVIEW_SERVED_SLOW, "no patience left -> slow")


func test_review_for_served_clamps_degenerate_fractions() -> void:
	assert_eq(StoreRating.review_for_served(1.5), StoreRating.REVIEW_SERVED_FAST, "over 1.0 clamps to top")
	assert_eq(StoreRating.review_for_served(-0.5), StoreRating.REVIEW_SERVED_SLOW, "negative clamps to slow")


func test_unrated_until_first_review() -> void:
	assert_true(StoreRating.is_unrated(0), "zero reviews -> unrated")
	assert_false(StoreRating.is_unrated(1), "one review -> rated")


func test_rating_climbs_gradually_to_the_tuned_target() -> void:
	# Tuned headline (C=2.8): 10 fast, perfect serves (50 points) land ~3.9★, not 5.
	assert_true(_approx(StoreRating.rating(50, 10), 3.9, 0.05), "10 perfect reviews -> ~3.9")
	# One 5★ review is heavily damped; sustained perfect play approaches but never reaches
	# 5.0 (the prior keeps a ceiling just out of reach).
	assert_true(StoreRating.rating(5, 1) < 2.0, "one 5★ review is heavily damped")
	assert_true(StoreRating.rating(500, 100) < 5.0, "even 100 perfect reviews stay under 5.0")
	assert_true(StoreRating.rating(500, 100) > StoreRating.rating(50, 10), "more good reviews -> higher")


func test_established_rating_is_robust_to_one_bad_review() -> void:
	# 30 perfect reviews, then one 1★: the rating barely moves (the 'fun to maintain'
	# property). Before: 150/(2+30); after: 151/(2+31).
	var before := StoreRating.rating(150, 30)
	var after := StoreRating.rating(150 + 1, 31)
	assert_true(before - after < 0.15, "one bad review dents an established rating only slightly")
	assert_true(after < before, "...but it does dent it")


func test_star_string_rounds_to_nearest_half_and_is_fixed_width() -> void:
	assert_eq(StoreRating.star_string(1.7), "★½☆☆☆", "1.7 -> one full, a half, three empty")
	assert_eq(StoreRating.star_string(4.5), "★★★★½", "4.5 -> four full + half")
	assert_eq(StoreRating.star_string(0.0), "☆☆☆☆☆", "0 -> all empty")
	assert_eq(StoreRating.star_string(5.0), "★★★★★", "5 -> all full")
	for v in [0.0, 1.3, 2.5, 3.8, 4.6, 5.0]:
		assert_eq(StoreRating.star_string(v).length(), StoreRating.MAX_STARS,
			"rating %s -> 5 glyphs" % v)


func test_summary_unrated_then_rated_with_pluralisation() -> void:
	assert_eq(StoreRating.summary(0, 0), "Unrated · no reviews yet", "zero reviews -> Unrated")
	assert_eq(StoreRating.summary(5, 1), "★½☆☆☆  1.3  (1 review)", "singular 'review' at one")
	assert_eq(StoreRating.summary(50, 10), "★★★★☆  3.9  (10 reviews)", "plural; the tuned 10-perfect example")
