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
	"second_counter": {
		"label": "Second Counter",
		"effect_text": "+2 customers per shift",
		"base_cost": 120,
		"cost_step": 80,
		"max_level": 3,
		"target": "wave_size",
		"effect_per_level": 2.0,
		# Tree v1 (issue #3): the first *gated* upgrade. Locked until Counter Space
		# reaches Lv 2 — you grow the counter before adding a second one. A deeper,
		# pricier, stronger wave_size tier than counter_space (which it stacks with,
		# since apply_to_shift sums every wave_size contributor). Placeholder tuning
		# (CONTEXT.md defers numbers) — flagged for a feel pass.
		"requires": {"id": "counter_space", "level": 2},
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
	"clerk": {
		"label": "Hire a Clerk",
		"effect_text": "Auto-serves the front customer alongside you",
		# Costs 100 / 400 / 700 (base + step*level). Deliberately steep: the clerk is a
		# long-term idle unlock, so each level is several days of takings, not pocket
		# change — reaching a steady auto-served shift should feel earned. Placeholder
		# tuning (CONTEXT.md defers numbers).
		"base_cost": 100,
		"cost_step": 300,
		"max_level": 3,
		# target is "" (and effect_per_level 0.0) because the clerk maps to
		# ServeDriver cadence — it is driver-owned, not a Shift field — so it does
		# NOT flow through apply_to_shift(); ServeDriver reads level_of("clerk").
		"target": "",
		"effect_per_level": 0.0,
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


## The prerequisite for `id`, as {"id": String, "level": int}, or {} if it has none.
## This is the upgrade-tree edge (issue #3): a gated upgrade names another upgrade
## it must reach before it can be bought.
func requirement_of(id: String) -> Dictionary:
	if not CATALOG.has(id):
		return {}
	return CATALOG[id].get("requires", {})


## True if `id` has no prerequisite, or its prerequisite is met (the required
## upgrade is at or above the required level). Unknown ids are never unlocked —
## there is nothing to buy.
func is_unlocked(id: String) -> bool:
	var req: Dictionary = requirement_of(id)
	if req.is_empty():
		return CATALOG.has(id)
	return level_of(String(req["id"])) >= int(req["level"])


## Can the player buy the next level right now? False for unknown / maxed / too dear.
func can_afford(id: String) -> bool:
	if not CATALOG.has(id):
		return false
	if is_maxed(id):
		return false
	return int(_state.money) >= cost_of(id)


## The full purchase gate: prerequisite met, known, not maxed, and affordable.
## buy() is exactly can_buy() with the side effect.
func can_buy(id: String) -> bool:
	return is_unlocked(id) and can_afford(id)


## Attempt to buy the next level of `id`. Returns true on a purchase. Unknown,
## locked (prerequisite unmet), maxed, or unaffordable is a harmless no-op
## (returns false); money and levels never go negative.
func buy(id: String) -> bool:
	if not can_buy(id):
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
## Every catalog entry whose `target` names a Shift field contributes its
## effect, so multiple upgrades can stack on the same field (e.g. counter_space
## and second_counter both raise wave_size) and a new upgrade only needs a
## catalog entry — no change here. Entries with an empty target (the clerk, which
## is ServeDriver-owned) contribute nothing.
func apply_to_shift(shift) -> void:
	var wave_bonus: int = 0
	var patience_bonus: float = 0.0
	for id in CATALOG:
		match String(CATALOG[id]["target"]):
			"wave_size":
				wave_bonus += int(effect_of(id, level_of(id)))
			"patience":
				patience_bonus += effect_of(id, level_of(id))
	shift.wave_size = ShiftScript.DEFAULT_WAVE_SIZE + wave_bonus
	shift.patience = ShiftScript.DEFAULT_PATIENCE + patience_bonus
