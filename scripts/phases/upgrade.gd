extends Control
## Upgrade — the UPGRADE phase screen (v1). Renders the upgrade catalog as a list
## of buyable rows and drives a headless-testable `UpgradeShop`
## (scripts/phases/upgrade_shop.gd) that owns all the rules and pricing. Money and
## owned levels flow through GameState; when the player is done, "Start next day ->"
## hands the day on via DayCycle.advance() (UPGRADE -> next day, which saves).
##
## This layer is presentation only: every rule (cost, affordability, max level)
## lives in UpgradeShop. The screen stays usable at 0 kr — every Buy is just
## disabled and Start next day still works.

const UpgradeShopScript := preload("res://scripts/phases/upgrade_shop.gd")

@onready var _money: Label = %Money
@onready var _list: VBoxContainer = %UpgradeList
@onready var _next_day_btn: Button = %NextDayButton

var _shop
var _buttons: Dictionary = {}  ## upgrade_id -> its Buy Button
var _rows: Dictionary = {}     ## upgrade_id -> the row's status Label


func _ready() -> void:
	_shop = UpgradeShopScript.new(GameState)
	_shop.changed.connect(_refresh)
	for id in UpgradeShopScript.CATALOG:
		_add_row(id)
	_next_day_btn.pressed.connect(DayCycle.advance)  # UPGRADE -> next day; Main swaps the scene
	_refresh()


## Build one catalog row: name + effect/owned-level status, and a Buy button keyed
## by id. The button routes its click straight to UpgradeShop.buy(id).
func _add_row(id: String) -> void:
	var entry: Dictionary = UpgradeShopScript.CATALOG[id]
	var row := PanelContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [entry["label"], entry["effect_text"]]
	var status_lbl := Label.new()
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(name_lbl)
	info.add_child(status_lbl)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(150, 0)
	buy_btn.pressed.connect(_shop.buy.bind(id))

	hb.add_child(info)
	hb.add_child(buy_btn)
	_list.add_child(row)
	_buttons[id] = buy_btn
	_rows[id] = status_lbl


func _refresh() -> void:
	if _shop == null:
		return
	_money.text = "%d kr" % int(GameState.money)
	for id in UpgradeShopScript.CATALOG:
		var status: Label = _rows[id]
		var btn: Button = _buttons[id]
		var level: int = _shop.level_of(id)
		if _shop.is_maxed(id):
			status.text = "Level %d — Maxed" % level
			btn.text = "MAX"
		else:
			status.text = "Level %d" % level
			btn.text = "Buy — %d kr" % _shop.cost_of(id)
		btn.disabled = _shop.is_maxed(id) or not _shop.can_afford(id)
