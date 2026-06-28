extends Control
## Serve — the SERVE phase screen (v1). Renders the customer queue and product
## buttons, and drives a headless-testable `Shift` (scripts/phases/shift.gd) that
## owns all the rules. Money and stock flow through GameState; when the wave ends,
## the shift hands the day on via DayCycle.advance() (SERVE -> UPGRADE).
##
## Input is click-to-serve for now. Per the roadmap this layer later becomes
## drag-to-customer, then a purchasable click upgrade, then auto-serve — all of
## which just call Shift.serve()/prep_step(), so only this input layer changes.

const ShiftScript := preload("res://scripts/phases/shift.gd")
const UpgradeShopScript := preload("res://scripts/phases/upgrade_shop.gd")
const ServeDriverScript := preload("res://scripts/phases/serve_driver.gd")
const DayScalingScript := preload("res://scripts/day_scaling.gd")

## Danish first names for queue flavor (presentation only — not in the model).
const NAMES := ["Anders", "Mette", "Lars", "Sofie", "Freja", "Mads", "Ida",
	"Emil", "Oliver", "Clara", "Noah", "Alma"]

const FRESH := Color(0.30, 0.78, 0.34)   ## patience-bar colour, full
const URGENT := Color(0.90, 0.22, 0.22)  ## patience-bar colour, nearly out
const WANTED := Color(0.62, 1.0, 0.62)   ## highlight for the needed product button

## Clerk on-duty badge (the automation bridge was previously invisible — the clerk
## silently drained the queue). CLERK_IDLE is the resting tint; each time the clerk
## actually serves/preps it pulses to CLERK_ACTED and fades back over CLERK_FLASH.
## Presentation only — it reads ServeDriver, never drives the rules. Needs an F5
## pass to judge the feel.
const CLERK_IDLE := Color(0.62, 0.78, 1.0)   ## on-duty, between actions
const CLERK_ACTED := Color(0.40, 1.0, 0.55)  ## brief pulse when it serves/preps
const CLERK_FLASH := 0.45                    ## seconds the pulse takes to fade

@onready var _scoreboard: Label = %Scoreboard
@onready var _queue_line: HBoxContainer = %QueueLine
@onready var _empty_hint: Label = %EmptyHint
@onready var _prep_label: Label = %PrepLabel
@onready var _buttons_box: HBoxContainer = %Buttons

var _shift
var _driver                       ## the auto-serve clerk (ServeDriver), a second caller of Shift
var _product_buttons: Dictionary = {}  ## product_id -> its serve Button
var _cards: Dictionary = {}       ## Customer -> card Control
var _names: Dictionary = {}       ## Customer -> display name
var _arrivals: int = 0
var _clerk_label: Label = null    ## "Clerk on duty" badge; null when no clerk is hired
var _clerk_flash: float = 0.0     ## seconds left on the act-pulse highlight


func _ready() -> void:
	_shift = ShiftScript.new(GameState)
	var shop = UpgradeShopScript.new(GameState)
	shop.apply_to_shift(_shift)
	# Day-driven escalation (issue #2): later days bring a busier wave. Applied on
	# top of the upgrade tuning so the two compose — a gentle, bounded ramp that
	# keeps the shift no-fail (CONTEXT.md).
	_shift.wave_size += DayScalingScript.wave_bonus(GameState.day)
	# Rating-gated product lines: only products the store's best-ever rating has unlocked
	# can be wanted or served (e.g. parcels need 4.0★ — see Shift.unlocked_product_ids).
	# Sticky via GameState.best_rating, so an earned unlock can't be lost to a later dip.
	var unlocked: Array = ShiftScript.unlocked_product_ids(GameState.best_rating)
	_shift.available_products = unlocked
	# One serve button per UNLOCKED product, built from the catalog — adding a product
	# line needs only a PRODUCTS entry, no scene edit. Each routes its click to
	# _serve(id); the prep flow is keyed off PRODUCTS[id].prep inside _serve.
	for id in unlocked:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 72)
		btn.pressed.connect(_serve.bind(id))
		_buttons_box.add_child(btn)
		_product_buttons[id] = btn
	# The clerk reads its hired level once, at shift start: a clerk hired mid-UPGRADE
	# takes effect the next shift (CONTEXT.md invariant 3: the day is the unit). It is
	# purely additive — a second caller beside _serve(), never a gate on the buttons.
	_driver = ServeDriverScript.new(_shift, shop.level_of("clerk"))
	_shift.customer_arrived.connect(_on_customer_arrived)
	_shift.customer_served.connect(_on_customer_served)
	_shift.customer_left.connect(_on_customer_left)
	_shift.shift_ended.connect(_on_shift_ended)
	_maybe_add_clerk_indicator()
	_shift.start()
	_refresh()


## A "Clerk on duty" badge, shown only when a clerk is hired, so the automation
## bridge is visible instead of silently draining the queue. Built at runtime (like
## Main's welcome-back banner) and slotted right under the Header, so the Serve scene
## file needs no edit. The cadence text tells the player how fast the clerk is; the
## per-action pulse (driven from _process) shows it working. Presentation only.
func _maybe_add_clerk_indicator() -> void:
	if _driver == null or not _driver.is_active():
		return
	var vbox: Node = _buttons_box.get_parent()  # Buttons is a direct child of the VBox
	_clerk_label = Label.new()
	_clerk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clerk_label.text = "● Clerk on duty — lends a hand every %.1fs" % _driver.cadence()
	_clerk_label.modulate = CLERK_IDLE
	vbox.add_child(_clerk_label)
	vbox.move_child(_clerk_label, 1)  # just below the Header row


func _process(delta: float) -> void:
	if _shift == null or _shift.is_over:
		return
	_shift.tick(delta)
	# tick() returns true on a frame where the clerk actually served or prepped —
	# that's the cue to pulse the on-duty badge.
	if _driver != null and _driver.tick(delta):
		_clerk_flash = CLERK_FLASH
	_update_clerk_indicator(delta)
	_refresh()


## Fade the clerk badge from CLERK_ACTED back to CLERK_IDLE after each action.
func _update_clerk_indicator(delta: float) -> void:
	if _clerk_label == null:
		return
	_clerk_flash = maxf(_clerk_flash - delta, 0.0)
	_clerk_label.modulate = CLERK_IDLE.lerp(CLERK_ACTED, _clerk_flash / CLERK_FLASH)


## One click on a product. For the hot dog, the click first advances prep (bun ->
## sausage); the click that lands after prep is complete hands it over.
func _serve(id: String) -> void:
	if _shift == null or _shift.is_over:
		return
	if ShiftScript.PRODUCTS[id]["prep"] and _shift.prep_step():
		_refresh()
		return
	_shift.serve(id)
	_refresh()


func _on_customer_arrived(c) -> void:
	var who: String = NAMES[_arrivals % NAMES.size()]
	_arrivals += 1
	_names[c] = who
	var card := _make_card(c, who)
	_cards[c] = card
	_queue_line.add_child(card)


func _on_customer_served(c, _price: int) -> void:
	_remove_card(c)


func _on_customer_left(c) -> void:
	_remove_card(c)


func _on_shift_ended() -> void:
	set_process(false)
	# Reviews are summed at day's end: fold this shift's tally into the lifetime rating
	# now, before UPGRADE, so the new rating (and any freshly-unlocked tiers) are live on
	# tonight's UPGRADE screen and tomorrow's PROCURE.
	GameState.commit_reviews(_shift.review_points, _shift.review_count)
	DayCycle.advance()  # SERVE -> UPGRADE; Main swaps in the next phase scene


func _remove_card(c) -> void:
	var card = _cards.get(c)
	if card != null:
		card.queue_free()
		_cards.erase(c)
	_names.erase(c)


func _refresh() -> void:
	if _shift == null:
		return
	_scoreboard.text = "Served %d    ·    Lost %d    ·    Wave %d/%d" % [
		_shift.served_count, _shift.lost_sales,
		min(_shift.total_arrived(), _shift.wave_size), _shift.wave_size]
	_empty_hint.visible = _shift.queue.is_empty()

	var active = _shift.active_customer()
	for c in _cards:
		var card: Control = _cards[c]
		var bar: ProgressBar = card.get_node("VB/Patience")
		bar.max_value = c.max_patience
		bar.value = maxf(c.patience, 0.0)
		var frac := clampf(c.patience / c.max_patience, 0.0, 1.0)
		bar.modulate = URGENT.lerp(FRESH, frac)
		var is_active: bool = c == active
		card.modulate = Color.WHITE if is_active else Color(1, 1, 1, 0.45)
		var name_lbl: Label = card.get_node("VB/Name")
		name_lbl.text = ("▶ " if is_active else "") + String(_names.get(c, ""))

	# Each product button shows its price + live stock and lights up when it's the
	# one the front customer wants — same treatment for every product line.
	var want: String = active.product_id if active != null else ""
	for id in _product_buttons:
		var btn: Button = _product_buttons[id]
		btn.text = _btn_text(id)
		btn.modulate = WANTED if want == id else Color.WHITE

	if active != null and ShiftScript.PRODUCTS[active.product_id]["prep"]:
		var p: Dictionary = ShiftScript.PRODUCTS[active.product_id]
		var hint: String = p.get("prep_hint", "prepare, then hand over")
		_prep_label.visible = true
		_prep_label.text = "%s prep %d/%d — click %s: %s" % [
			p["label"], _shift.prep_progress, ShiftScript.PREP_STEPS, p["label"], hint]
	else:
		_prep_label.visible = false


func _btn_text(id: String) -> String:
	var p: Dictionary = ShiftScript.PRODUCTS[id]
	return "%s\n%d kr · stock %d" % [p["label"], p["price"], int(GameState.stock.get(id, 0))]


func _make_card(c, who: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 0)
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)
	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.text = who
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var order_lbl := Label.new()
	order_lbl.name = "Order"
	order_lbl.text = "wants\n" + ShiftScript.PRODUCTS[c.product_id]["label"]
	order_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := ProgressBar.new()
	bar.name = "Patience"
	bar.show_percentage = false
	bar.max_value = c.max_patience
	bar.value = c.patience
	bar.custom_minimum_size = Vector2(0, 10)
	vb.add_child(name_lbl)
	vb.add_child(order_lbl)
	vb.add_child(bar)
	return card
