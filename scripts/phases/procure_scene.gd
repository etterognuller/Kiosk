extends Control
## Procure — the PROCURE phase screen (v1). Renders one buy row per product and
## drives a headless-testable `Procure` (scripts/phases/procure.gd) that owns all
## the rules. Money and stock flow through GameState; "Open shop →" hands the day
## on via DayCycle.advance() (PROCURE -> SERVE).
##
## This layer is pure presentation: it never decides what's affordable — the buy
## buttons always call Procure.buy(), which clamps to the wallet, so an empty
## purse just makes them harmless no-ops. "Open shop →" is always enabled, since
## opening with zero stock is allowed (it just means lost sales mid-shift).

const ProcureScript := preload("res://scripts/phases/procure.gd")

@onready var _wallet: Label = %Wallet
@onready var _rows: VBoxContainer = %Rows
@onready var _open_btn: Button = %OpenButton

var _logic
var _row_labels: Dictionary = {}  ## product_id -> the row's Label


func _ready() -> void:
	_logic = ProcureScript.new(GameState)
	_logic.stock_changed.connect(_refresh)
	for id in ProcureScript.CATALOG:
		_rows.add_child(_make_row(id))
	_open_btn.pressed.connect(DayCycle.advance)  # PROCURE -> SERVE
	_refresh()


func _buy(id: String, qty: int) -> void:
	_logic.buy(id, qty)
	_refresh()


func _refresh() -> void:
	if _logic == null:
		return
	_wallet.text = "Money %d kr" % int(GameState.money)
	for id in _row_labels:
		var cost := int(ProcureScript.CATALOG[id]["cost"])
		var label: String = ProcureScript.CATALOG[id]["label"]
		var have := int(GameState.stock.get(id, 0))
		_row_labels[id].text = "%s — %d kr each · have %d" % [label, cost, have]


func _make_row(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_row_labels[id] = label
	var plus_one := Button.new()
	plus_one.text = "+1"
	plus_one.pressed.connect(_buy.bind(id, 1))
	row.add_child(plus_one)
	var plus_five := Button.new()
	plus_five.text = "+5"
	plus_five.pressed.connect(_buy.bind(id, 5))
	row.add_child(plus_five)
	return row
