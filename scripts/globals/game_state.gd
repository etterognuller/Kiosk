extends Node
## GameState — the savable data model for a playthrough.
##
## This is deliberately tiny for v1: money is the only number, plus the day
## counter, a stock dictionary, and a last-saved timestamp. The timestamp is
## here from day one because offline/idle time is measured in *days away* later
## (see CONTEXT.md invariant: "the day is the unit"). Keep this script free of
## gameplay logic — it just holds state and reads/writes the save file.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

## Placeholder starting values. Real economic tuning is deferred (CONTEXT.md).
const STARTING_MONEY := 50

## Reputation (customer satisfaction) starts neutral on a 0..100 scale, so it reads
## like a satisfaction percentage and has clear headroom both ways. Placeholder
## tuning (CONTEXT.md); the clamp range lives with the movement logic in Shift.
const STARTING_REPUTATION := 50

## Clean money, in Danish kroner. (Dirty money / two-currency economy is a
## later-phase concern and intentionally absent in v1.)
var money: int = STARTING_MONEY

## Customer satisfaction, 0..100. Soft pressure only — a low number slows progress
## but never ends the game (CONTEXT.md: no-fail / cozy). Moved by Shift (a serve
## raises it, a lost sale lowers it); downstream effects (tips, spawn rate) are a
## later concern. It is a second number the player wants to keep high.
## Later (ROADMAP "Polish"): present this as a 1..5 star rating (Trustpilot-style)
## for realism — a display mapping over this same stored number, not a model change.
var reputation: int = STARTING_REPUTATION

## The current day number. Days are the run / save / idle unit.
var day: int = 1

## product_id -> units on hand. The v1 product set; numbers are placeholders.
var stock: Dictionary = {
	"cigarettes": 0,
	"soda": 0,
	"hotdog": 0,
	"parcels": 0,
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
	reputation = STARTING_REPUTATION
	day = 1
	stock = {"cigarettes": 0, "soda": 0, "hotdog": 0, "parcels": 0}
	upgrades = {"counter_space": 0, "second_counter": 0, "loyalty_cards": 0, "clerk": 0}
	last_saved_unix = 0


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"money": money,
		"reputation": reputation,
		"day": day,
		"stock": stock,
		"upgrades": upgrades,
		"last_saved_unix": last_saved_unix,
	}


func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	reputation = int(data.get("reputation", reputation))
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
