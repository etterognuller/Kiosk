extends RefCounted
## Shift — the pure, UI-free logic of one SERVE shift (v1).
##
## A fixed wave of customers queue up, each wanting one product. The player serves
## the front (active) customer; a successful serve adds money and consumes one unit
## of stock. Running out of stock or letting a patience timer expire is a *lost
## sale*, never a crash (CONTEXT.md: no-fail / cozy). The shift ends once the whole
## wave has arrived and the queue is empty; the scene then hands control back to
## the day loop via DayCycle.advance() (SERVE -> UPGRADE).
##
## Deliberately decoupled from both the scene and the input method. It exposes
## serve(product_id) / prep_step() and does not care whether those came from a
## click, a drag, or an automated clerk — v1 input is click-to-serve, but the
## roadmap moves to drag-to-customer, then a purchasable click upgrade, then
## auto-serve, all driving this same API. Money and stock are read/written through
## an injected GameState-shaped object (anything with `money: int` and
## `stock: Dictionary`) so the logic unit-tests without the autoload graph
## (see tests/README.md).

signal customer_arrived(customer)            ## a new customer joined the queue
signal customer_served(customer, price: int) ## served and paid; left happy
signal customer_left(customer)               ## patience expired, or a stockout
signal prep_changed(progress: int, total: int) ## hot dog prep state for the active customer
signal shift_ended()                         ## fires exactly once, when the wave is done

## Pulled in for the review scoring + floor (REVIEW_LOST). The rating math itself
## lives in StoreRating; Shift just records each review into the injected state.
const StoreRating := preload("res://scripts/store_rating.gd")

## v1 product catalog. Prices are placeholder tuning (CONTEXT.md defers numbers).
## `prep` marks the light-prep path (hot dog) vs an instant grab-and-ring sale.
const PRODUCTS := {
	"cigarettes": {"label": "Cigarettes", "price": 6, "prep": false},
	"soda": {"label": "Soda", "price": 5, "prep": false},
	"hotdog": {"label": "Hot dog", "price": 12, "prep": true, "prep_hint": "bun → sausage → hand over"},
	# Pakkeshop parcel line (issue #4): an instant grab-and-ring sale, no prep —
	# the signature Danish kiosk staple. Placeholder price (CONTEXT.md), kept above
	# its wholesale cost so it turns a margin. Rating-gated: the forwarders only set up
	# once the store has earned a 4.0★ reputation (see unlocked_product_ids; the gate is
	# sticky via GameState.best_rating). Placeholder threshold (CONTEXT.md) — flag for F5.
	# `unlock_blurb` is the one-shot celebration copy shown when the gate is first crossed
	# (Main reads it; any future gated line supplies its own).
	"parcels": {"label": "Parcel", "price": 8, "prep": false, "requires_rating": 4.0,
		"unlock_blurb": "The pakkeshop forwarders saw your reviews and moved in — parcels are yours to handle."},
	# Second product tier (issue #5): coffee — a higher-value signature item that
	# reuses the light-prep mechanic (its own flavour hint, same PREP_STEPS depth).
	# Premium retail above the hot dog; placeholder tuning (CONTEXT.md). Available
	# from the start (the thin path #4 established); gating it behind a future
	# "Coffee Machine" upgrade is a natural follow-up now #3's prerequisites exist.
	"coffee": {"label": "Coffee", "price": 15, "prep": true, "prep_hint": "grind → pour → hand over"},
}

## Optional per-prep-product flavour for the prep prompt ("bun → sausage → hand
## over"). `prep_hint` is read by the SERVE screen only; the rules ignore it.

## Hot dog prep: clicks needed before it can be handed over (bun -> sausage). The
## serve itself is the final "hand over", so the player clicks the hot dog three
## times total: bun, sausage, hand over.
const PREP_STEPS := 2

## Placeholder shift tuning, sized for a readable ~30s wave. Exposed as instance
## vars (defaulting to these) so tests can shrink a wave and the scene can tune
## feel without touching the constants.
const DEFAULT_WAVE_SIZE := 8        ## customers per shift (the fixed-wave end condition)
const DEFAULT_SPAWN_INTERVAL := 2.5 ## seconds between arrivals
const DEFAULT_PATIENCE := 10.0      ## seconds a customer waits before leaving

## Customer reviews drive the store rating (Reputation v2). Every resolved customer
## leaves exactly one review: a served customer's score scales with how promptly they
## were served (StoreRating.review_for_served), a lost sale — stockout or an expired
## patience timer — scores the floor (StoreRating.REVIEW_LOST). The score values and
## the rating math live in StoreRating; Shift just records each review into the
## injected state's running totals. No clamp / fail state — a bad run simply earns low
## reviews (CONTEXT.md: no-fail / cozy). The rating has no downstream effect yet.

var wave_size: int = DEFAULT_WAVE_SIZE
var spawn_interval: float = DEFAULT_SPAWN_INTERVAL
var patience: float = DEFAULT_PATIENCE

## The product ids customers can want this shift, in spawn-rotation order. Defaults to
## the whole catalog (set in _init); serve.gd narrows it to the rating-unlocked set so a
## locked line (parcels below 4.0★) never spawns a customer. Set before start().
var available_products: Array = []

## This shift's running review tally (kept here like served_count / lost_sales). serve.gd
## folds it into GameState's lifetime totals when the shift ends — reviews are summed at
## day's end, not applied live (Reputation v2).
var review_points: int = 0
var review_count: int = 0

## When false, tick() stops spawning new arrivals — a test seam so serve/patience
## logic can be exercised on a hand-built queue. The scene always leaves it true.
var auto_spawn: bool = true

## A single customer: wants one product, waits `patience` seconds.
class Customer extends RefCounted:
	var product_id: String
	var patience: float
	var max_patience: float
	func _init(p_id: String, p_patience: float) -> void:
		product_id = p_id
		patience = p_patience
		max_patience = p_patience

var queue: Array = []        ## waiting customers; index 0 is the active one
var served_count: int = 0
var lost_sales: int = 0
var prep_progress: int = 0   ## prep steps done for the active hot dog order
var is_over: bool = false

var _state                   ## GameState-shaped: `money: int`, `stock: Dictionary`
var _spawned: int = 0        ## how many of the wave have arrived so far
var _spawn_timer: float = 0.0
var _started: bool = false


func _init(state) -> void:
	_state = state
	available_products = PRODUCTS.keys()  # full catalog by default; serve.gd narrows it


## Begin the shift; the first customer arrives immediately.
func start() -> void:
	if _started:
		return
	_started = true
	_spawn_timer = spawn_interval
	_spawn_customer()


## Advance timers: stagger in new arrivals and expire impatient customers. Every
## waiting customer loses patience (not just the active one), so a long line is
## real pressure — the core challenge of the Serving pillar.
func tick(delta: float) -> void:
	if is_over:
		return
	if auto_spawn and _spawned < wave_size:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer += spawn_interval
			_spawn_customer()
	# Iterate back-to-front so removals don't skip anyone.
	var i := queue.size() - 1
	while i >= 0:
		var c: Customer = queue[i]
		c.patience -= delta
		if c.patience <= 0.0:
			_remove_customer(i, true)
		i -= 1
	_check_end()


## The front customer the player is currently serving, or null if the queue is empty.
func active_customer() -> Customer:
	return queue[0] if not queue.is_empty() else null


## The product ids unlocked at `rating`, in catalog order. A product with no
## "requires_rating" is always available; a gated one (e.g. parcels at 4.0★) appears
## only once the rating reaches its threshold. serve.gd / procure pass the sticky
## GameState.best_rating, so an unlock, once earned, stays. Pure catalog query.
static func unlocked_product_ids(rating: float) -> Array:
	var ids: Array = []
	for id in PRODUCTS:
		if rating >= float(PRODUCTS[id].get("requires_rating", 0.0)):
			ids.append(id)
	return ids


## The product ids whose rating gate is newly crossed going from `old_rating` to
## `new_rating` — i.e. gated lines that were locked before and are unlocked now. Pure
## set difference over unlocked_product_ids; serve.gd calls it the moment a shift's
## reviews lift best_rating, to fire the one-shot unlock celebration. Empty when nothing
## crossed (the common case), so the caller can just check is_empty().
static func newly_unlocked_product_ids(old_rating: float, new_rating: float) -> Array:
	var before := unlocked_product_ids(old_rating)
	return unlocked_product_ids(new_rating).filter(func(id): return id not in before)


## Attempt to serve `product_id` to the active customer. Returns true on a sale.
## Input-method agnostic: click, drag, or an auto-serve clerk all route here.
func serve(product_id: String) -> bool:
	if is_over:
		return false
	var c := active_customer()
	if c == null:
		return false
	if c.product_id != product_id:
		return false  # wrong product — harmless no-op, no penalty in v1
	if PRODUCTS[product_id]["prep"] and prep_progress < PREP_STEPS:
		return false  # hot dog isn't prepped yet; can't hand it over
	var on_hand := int(_state.stock.get(product_id, 0))
	if on_hand <= 0:
		# Stockout: a lost sale, never a negative balance. The customer leaves unhappy.
		queue.pop_front()
		lost_sales += 1
		_record_review(StoreRating.REVIEW_LOST)
		customer_left.emit(c)
		_reset_prep()
		_check_end()
		return false
	# Success: take the money, consume one unit, customer leaves happy.
	var price := int(PRODUCTS[product_id]["price"])
	_state.money += price
	_state.stock[product_id] = on_hand - 1
	served_count += 1
	# Promptness-scaled review: a customer served with patience to spare leaves a
	# better score than one served as their patience ran out.
	var promptness := c.patience / c.max_patience if c.max_patience > 0.0 else 1.0
	_record_review(StoreRating.review_for_served(promptness))
	queue.pop_front()
	customer_served.emit(c, price)
	_reset_prep()
	_check_end()
	return true


## Advance the active hot dog's prep by one step (bun, then sausage). Returns true
## if a step was taken. No-op if the active customer doesn't want a hot dog or prep
## is already complete (so the scene can route every click here first, then serve).
func prep_step() -> bool:
	if is_over:
		return false
	var c := active_customer()
	if c == null or not PRODUCTS[c.product_id]["prep"]:
		return false
	if prep_progress >= PREP_STEPS:
		return false
	prep_progress += 1
	prep_changed.emit(prep_progress, PREP_STEPS)
	return true


## How many of the wave have arrived (served, waiting, or already left). For HUD.
func total_arrived() -> int:
	return _spawned


func _spawn_customer() -> void:
	var ids := available_products
	# Deterministic rotation through the unlocked products — easy to read and to test; a
	# little randomness can come later when tuning feel. Locked lines aren't in `ids`,
	# so their customers never arrive.
	var pid: String = ids[_spawned % ids.size()]
	var c := Customer.new(pid, patience)
	queue.append(c)
	_spawned += 1
	customer_arrived.emit(c)
	if queue.size() == 1:
		_reset_prep()  # this arrival is the new active customer


func _remove_customer(index: int, lost: bool) -> void:
	if index < 0 or index >= queue.size():
		return
	var c: Customer = queue[index]
	queue.remove_at(index)
	if lost:
		lost_sales += 1
		_record_review(StoreRating.REVIEW_LOST)
		customer_left.emit(c)
	if index == 0:
		_reset_prep()  # the active customer changed


## Record one customer review into THIS shift's tally (Reputation v2). Reviews are not
## applied live — serve.gd folds this tally into GameState's lifetime totals when the
## shift ends, so the displayed rating is a stable daily verdict, not a twitchy live
## number. No clamp: the rating is a Bayesian average of the totals (see StoreRating).
func _record_review(stars: int) -> void:
	review_points += stars
	review_count += 1


func _reset_prep() -> void:
	prep_progress = 0
	var c := active_customer()
	var total := PREP_STEPS if (c != null and PRODUCTS[c.product_id]["prep"]) else 0
	prep_changed.emit(prep_progress, total)


func _check_end() -> void:
	if is_over:
		return
	# Fixed-wave end: the whole wave has arrived and nobody is left in the queue.
	if _started and _spawned >= wave_size and queue.is_empty():
		is_over = true
		shift_ended.emit()
