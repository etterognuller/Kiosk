extends Node
## GameState — the savable data model for a playthrough.
##
## This is deliberately tiny for v1: money is the only number, plus the day
## counter, a stock dictionary, and a last-saved timestamp. The timestamp is
## here from day one because offline/idle time is measured in *days away* later
## (see CONTEXT.md invariant: "the day is the unit"). Keep this script free of
## gameplay logic — it just holds state and reads/writes the save file.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 2

## Used only by commit_reviews to recompute best_rating from the review totals.
const StoreRating := preload("res://scripts/store_rating.gd")

## Placeholder starting values. Real economic tuning is deferred (CONTEXT.md).
const STARTING_MONEY := 50

## Clean money, in Danish kroner. (Dirty money / two-currency economy is a
## later-phase concern and intentionally absent in v1.)
var money: int = STARTING_MONEY

## The store's customer rating, stored as running review totals (Reputation v2). The
## displayed rating is a Bayesian average of all reviews ever — the mapping lives in
## StoreRating (scripts/store_rating.gd); this model only holds the sum of whole-star
## review scores and how many reviews have landed. A fresh store is Unrated (zero
## reviews) and earns its rating through service: Shift records one review per resolved
## customer (a prompt serve scores high, a lost sale scores 1). The rating has no
## mechanical effect yet — popularity, volume, and upgrades-via-popularity are deferred.
var review_points: int = 0
var review_count: int = 0

## Sticky best-ever rating, used to gate rating-locked content (e.g. the parcel line
## needs 4.0★). Gating reads this rather than the live rating so an unlock can't be lost
## to a later dip — once the parcel forwarders set up shop, they stay. Updated in
## commit_reviews; only ever rises. Persisted.
var best_rating: float = 0.0

## The current day number. Days are the run / save / idle unit.
var day: int = 1

## product_id -> units on hand. The v1 product set; numbers are placeholders.
var stock: Dictionary = {
	"cigarettes": 0,
	"soda": 0,
	"hotdog": 0,
	"parcels": 0,
	"coffee": 0,
}

## upgrade_id -> owned level. The UPGRADE phase's persistence; numbers are placeholders.
var upgrades: Dictionary = {
	"counter_space": 0,
	"second_counter": 0,
	"loyalty_cards": 0,
	"clerk": 0,
}

## Unix time of the last save. Used later to compute offline earnings in days.
var last_saved_unix: int = 0


## Reset to a fresh game. Called when there is no save to load.
func reset() -> void:
	money = STARTING_MONEY
	review_points = 0
	review_count = 0
	best_rating = 0.0
	day = 1
	stock = {"cigarettes": 0, "soda": 0, "hotdog": 0, "parcels": 0, "coffee": 0}
	upgrades = {"counter_space": 0, "second_counter": 0, "loyalty_cards": 0, "clerk": 0}
	last_saved_unix = 0


## Fold one shift's batch of reviews into the lifetime totals (Reputation v2: reviews
## are summed at the end of the day, not applied live). serve.gd calls this once when
## the shift ends, with the Shift's own tally. best_rating tracks the peak so unlocks
## stay sticky.
func commit_reviews(points: int, count: int) -> void:
	review_points += points
	review_count += count
	best_rating = maxf(best_rating, StoreRating.rating(review_points, review_count))


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"money": money,
		"review_points": review_points,
		"review_count": review_count,
		"best_rating": best_rating,
		"day": day,
		"stock": stock,
		"upgrades": upgrades,
		"last_saved_unix": last_saved_unix,
	}


func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	review_points = int(data.get("review_points", review_points))
	review_count = int(data.get("review_count", review_count))
	best_rating = float(data.get("best_rating", best_rating))
	day = int(data.get("day", day))
	stock = data.get("stock", stock)
	upgrades = data.get("upgrades", upgrades)
	last_saved_unix = int(data.get("last_saved_unix", 0))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	last_saved_unix = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: could not open save file for writing.")
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()


## Returns true if a save was found and loaded, false otherwise.
func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save file unreadable; starting fresh.")
		return false
	from_dict(parsed)
	return true
