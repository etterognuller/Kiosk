extends RefCounted
## UpgradeShop — the pure, UI-free logic of the UPGRADE phase (v1).
##
## After a shift, the player spends the day's takings on persistent upgrades that
## make tomorrow's shift easier. There is no fail state (CONTEXT.md: no-fail /
## cozy): an unaffordable or maxed-out purchase is a harmless no-op, never a crash,
## and money/levels never go negative. Levels persist in GameState.upgrades, so a
## bought upgrade carries across days (and across a save/load round-trip). The
## scene then hands the day on via DayCycle.advance() (UPGRADE -> next day).
##
## Deliberately decoupled from the scene. Money and owned levels are read/written
## through an injected GameState-shaped object (anything with `money: int` and
## `upgrades: Dictionary`) so the catalog and pricing unit-test without the autoload
## graph (see tests/README.md). The single place that maps an owned level to a
## gameplay effect is here (effect_of / apply_to_shift); serve.gd later calls
## apply_to_shift() to seed the next Shift's tuning.

## Pulled in only for the shift's default tuning constants (DEFAULT_WAVE_SIZE /
## DEFAULT_PATIENCE), which apply_to_shift offsets from. No Shift is constructed here.
const ShiftScript := preload("res://scripts/phases/shift.gd")

## v1 upgrade catalog. Ids MUST match GameState.upgrades' default keys. Costs and
## effects are placeholder tuning (CONTEXT.md defers numbers): cost rises by
## `cost_step` per owned level, `target` names the Shift field apply_to_shift
## offsets, and `effect_per_level` is how much one level adds to it.
const CATALOG := {
	"counter_space": {
		"label": "Counter Space",
		"effect_text": "+1 customer per shift",
		"base_cost": 30,
		"cost_step": 20,
		"max_level": 5,
		"target": "wave_size",
		"effect_per_level": 1.0,
	},
	"loyalty_cards": {
		"label": "Loyalty Cards",
		"effect_text": "+1.5s patience",
		"base_cost": 25,
		"cost_step": 25,
		"max_level": 5,
		"target": "patience",
		"effect_per_level": 1.5,
	},
}

signal changed()  ## a purchase landed; money and/or a level changed

var _state  ## GameState-shaped: `money: int`, `upgrades: Dictionary`


func _init(state) -> void:
	_state = state


## Owned level of an upgrade. Tolerates a missing key (a fresh / partial save).
func level_of(id: String) -> int:
	return int(_state.upgrades.get(id, 0))


## Price of the *next* level of `id`, rising by cost_step per level already owned.
func cost_of(id: String) -> int:
	var entry: Dictionary = CATALOG[id]
	return int(entry["base_cost"]) + int(entry["cost_step"]) * level_of(id)


## True once the upgrade is at its max level — no further purchases.
func is_maxed(id: String) -> bool:
	return level_of(id) >= int(CATALOG[id]["max_level"])


## Can the player buy the next level right now? False for unknown / maxed / too dear.
func can_afford(id: String) -> bool:
	if not CATALOG.has(id):
		return false
	if is_maxed(id):
		return false
	return int(_state.money) >= cost_of(id)


## Attempt to buy the next level of `id`. Returns true on a purchase. Unknown,
## maxed, or unaffordable is a harmless no-op (returns false); money and levels
## never go negative.
func buy(id: String) -> bool:
	if not can_afford(id):
		return false
	_state.money = int(_state.money) - cost_of(id)
	_state.upgrades[id] = level_of(id) + 1
	changed.emit()
	return true


## The effect contributed by owning `level` of `id` (level 0 -> 0). The only
## level -> effect mapping in the codebase; apply_to_shift is its one consumer.
func effect_of(id: String, level: int) -> float:
	return float(CATALOG[id]["effect_per_level"]) * level


## Seed a fresh Shift's tuning from the owned upgrade levels, offsetting each
## target field from the Shift's default. serve.gd calls this before start().
func apply_to_shift(shift) -> void:
	shift.wave_size = ShiftScript.DEFAULT_WAVE_SIZE + int(effect_of("counter_space", level_of("counter_space")))
	shift.patience = ShiftScript.DEFAULT_PATIENCE + effect_of("loyalty_cards", level_of("loyalty_cards"))
