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

@onready var _scoreboard: Label = %Scoreboard
@onready var _queue_line: HBoxContainer = %QueueLine
@onready var _empty_hint: Label = %EmptyHint
@onready var _prep_label: Label = %PrepLabel
@onready var _cig_btn: Button = %CigBtn
@onready var _soda_btn: Button = %SodaBtn
@onready var _hotdog_btn: Button = %HotdogBtn

var _shift
var _driver                   ## the auto-serve clerk (ServeDriver), a second caller of Shift
var _cards: Dictionary = {}   ## Customer -> card Control
var _names: Dictionary = {}   ## Customer -> display name
var _arrivals: int = 0


func _ready() -> void:
	_cig_btn.pressed.connect(_serve.bind("cigarettes"))
	_soda_btn.pressed.connect(_serve.bind("soda"))
	_hotdog_btn.pressed.connect(_serve.bind("hotdog"))

	_shift = ShiftScript.new(GameState)
	var shop = UpgradeShopScript.new(GameState)
	shop.apply_to_shift(_shift)
	# Day-driven escalation (issue #2): later days bring a busier wave. Applied on
	# top of the upgrade tuning so the two compose — a gentle, bounded ramp that
	# keeps the shift no-fail (CONTEXT.md). The clerk reads its level next.
	_shift.wave_size += DayScalingScript.wave_bonus(GameState.day)
	# The clerk reads its hired level once, at shift start: a clerk hired mid-UPGRADE
	# takes effect the next shift (CONTEXT.md invariant 3: the day is the unit). It is
	# purely additive — a second caller beside _serve(), never a gate on the buttons.
	_driver = ServeDriverScript.new(_shift, shop.level_of("clerk"))
	_shift.customer_arrived.connect(_on_customer_arrived)
	_shift.customer_served.connect(_on_customer_served)
	_shift.customer_left.connect(_on_customer_left)
	_shift.shift_ended.connect(_on_shift_ended)
	_shift.start()
	_refresh()


func _process(delta: float) -> void:
	if _shift == null or _shift.is_over:
		return
	_shift.tick(delta)
	if _driver != null:
		_driver.tick(delta)
	_refresh()


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

	_cig_btn.text = _btn_text("cigarettes")
	_soda_btn.text = _btn_text("soda")
	_hotdog_btn.text = _btn_text("hotdog")
	var want: String = active.product_id if active != null else ""
	_cig_btn.modulate = WANTED if want == "cigarettes" else Color.WHITE
	_soda_btn.modulate = WANTED if want == "soda" else Color.WHITE
	_hotdog_btn.modulate = WANTED if want == "hotdog" else Color.WHITE

	if active != null and ShiftScript.PRODUCTS[active.product_id]["prep"]:
		_prep_label.visible = true
		_prep_label.text = "Hot dog prep %d/%d — click Hot dog: bun → sausage → hand over" % [
			_shift.prep_progress, ShiftScript.PREP_STEPS]
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
