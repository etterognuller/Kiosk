extends RefCounted
## Procure — the pure, UI-free logic of one PROCURE turn (v1).
##
## Before opening the shop the player lays in stock for tomorrow: spend money at
## wholesale to buy units, which the SERVE shift then sells at retail. Buying is
## turn-based (no timers) — you can only spend what you have, and an unaffordable
## or zero/negative buy is a harmless no-op, never a negative balance or a crash
## (CONTEXT.md: no-fail / cozy). When the player opens the shop, the scene hands
## the day on via DayCycle.advance() (PROCURE -> SERVE).
##
## Like Shift, this is decoupled from the scene and reads/writes money and stock
## through an injected GameState-shaped object (anything with `money: int` and
## `stock: Dictionary`), so it unit-tests without the autoload graph
## (see tests/README.md).

signal stock_changed()  ## emitted only after a buy that actually changed stock

## Local mirror of the SERVE retail prices (shift.gd PRODUCTS[id].price). Used only
## by the drift-guard test, which asserts every CATALOG cost stays strictly below
## its sell price so procuring at wholesale can never out-cost retail.
const SELL_PRICES := {"cigarettes": 6, "soda": 5, "hotdog": 12}

## v1 wholesale catalog. Costs are placeholder tuning (CONTEXT.md defers numbers),
## kept strictly below SELL_PRICES so every unit sold turns a margin. Product ids
## match shift.gd's PRODUCTS so stock keys line up across phases.
const CATALOG := {
	"cigarettes": {"label": "Cigarettes", "cost": 3},
	"soda": {"label": "Soda", "cost": 2},
	"hotdog": {"label": "Hot dog", "cost": 6},
}

var _state  ## GameState-shaped: `money: int`, `stock: Dictionary`


func _init(state) -> void:
	_state = state


## Wholesale price for `qty` units of `product_id`. 0 for an unknown id or a
## non-positive qty (so a stray negative quantity can never refund money).
func cost_of(product_id: String, qty: int) -> int:
	if not CATALOG.has(product_id):
		return 0
	return int(CATALOG[product_id]["cost"]) * max(qty, 0)


## How many units of `product_id` the current balance could buy (integer division).
## 0 for an unknown id or a non-positive unit cost.
func max_affordable(product_id: String) -> int:
	if not CATALOG.has(product_id):
		return 0
	var unit := int(CATALOG[product_id]["cost"])
	if unit <= 0:
		return 0
	return int(_state.money) / unit


## True only if `qty` units are both wanted (qty > 0) and affordable in full.
func can_afford(product_id: String, qty: int) -> bool:
	return qty > 0 and qty <= max_affordable(product_id)


## Buy up to `qty` units of `product_id`, clamped to what the wallet allows.
## Returns the number actually bought (0 on a no-op). Spends money and adds stock
## only for the clamped amount, so money and stock are always >= 0.
func buy(product_id: String, qty: int) -> int:
	var amount := clampi(qty, 0, max_affordable(product_id))
	if amount == 0:
		return 0  # nothing to buy (unaffordable, unknown, or qty <= 0) — no signal
	_state.money -= cost_of(product_id, amount)
	_state.stock[product_id] = int(_state.stock.get(product_id, 0)) + amount
	stock_changed.emit()
	return amount


## Total units of all catalog products currently on hand. For the HUD.
func total_units() -> int:
	var sum := 0
	for id in CATALOG:
		sum += int(_state.stock.get(id, 0))
	return sum
