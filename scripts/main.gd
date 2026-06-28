extends Control
## Main — the root scene. Shows a minimal HUD (day / money / phase) and hosts the
## current phase's screen, swapping it whenever DayCycle reports a phase change.
## This is the visible proof that the day loop is wired end to end.

const StoreRating := preload("res://scripts/store_rating.gd")
const ShiftScript := preload("res://scripts/phases/shift.gd")

## Unlock-celebration palette — warmer/louder than the offline banner so a freshly
## earned product line reads as a milestone, not just a notice.
const UNLOCK_GOLD := Color(1.0, 0.84, 0.36)
const UNLOCK_PANEL_BG := Color(0.12, 0.10, 0.04, 0.96)

@onready var _day_label: Label = %DayLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _reputation_label: Label = %ReputationLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _phase_host: Control = %PhaseHost

## Phase enum value -> the scene shown for that phase. Built at runtime because
## the keys come from the DayCycle autoload.
var _phase_scenes: Dictionary = {}


func _ready() -> void:
	_phase_scenes = {
		DayCycle.Phase.PROCURE: preload("res://scenes/phases/Procure.tscn"),
		DayCycle.Phase.SERVE: preload("res://scenes/phases/Serve.tscn"),
		DayCycle.Phase.UPGRADE: preload("res://scenes/phases/Upgrade.tscn"),
	}
	DayCycle.phase_changed.connect(_on_phase_changed)
	DayCycle.day_started.connect(_on_day_started)
	_refresh_hud()
	_maybe_show_offline_banner()
	DayCycle.start()


## One-time "welcome back" banner for the days-away catch-up (issue #6). Game
## computed and granted the reward on boot; here we just surface it. Nothing to
## show on a fresh game or a sub-day gap. The banner is a transient runtime node
## that frees itself after a few seconds, so it needs no scene change.
func _maybe_show_offline_banner() -> void:
	var report: Dictionary = Game.last_offline_report
	if int(report.get("days", 0)) <= 0:
		return
	var days: int = int(report["days"])
	var reward: int = int(report["reward"])
	var banner := Label.new()
	banner.text = "Welcome back — %d day%s passed while you were away  (+%d kr)" % [
		days, "" if days == 1 else "s", reward,
	]
	banner.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.position.y += 40
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	get_tree().create_timer(6.0).timeout.connect(banner.queue_free)


## Poll the model each frame so money and reputation visibly move during a shift —
## the SERVE phase mutates GameState continuously, between phase_changed signals.
## Cheap: it only re-stamps four labels (Label.set_text no-ops on an equal value).
func _process(_delta: float) -> void:
	_refresh_hud()


func _on_day_started(_day: int) -> void:
	_refresh_hud()


func _on_phase_changed(phase: int) -> void:
	_refresh_hud()
	for child in _phase_host.get_children():
		child.queue_free()
	var scene: PackedScene = _phase_scenes.get(phase)
	if scene != null:
		_phase_host.add_child(scene.instantiate())
	# A shift can cross a rating gate (e.g. parcels at 4.0★); serve.gd stashes the
	# freshly-unlocked lines in Game.pending_unlocks just before this SERVE -> UPGRADE
	# swap. Celebrate them on the new screen so the unlock isn't silent.
	_maybe_show_unlock_banner()


## One-shot "new line unlocked!" celebration for any rating gate a shift just crossed
## (Game.pending_unlocks). A louder, gold sibling of the welcome-back banner: a centered
## card built at runtime (so no scene edit), naming each unlocked line and its blurb.
## Dismisses on click or after a few seconds. Consumes pending_unlocks so it fires once.
func _maybe_show_unlock_banner() -> void:
	var ids: Array = Game.pending_unlocks
	if ids.is_empty():
		return
	Game.pending_unlocks = []  # one-shot — clear before building so it can't re-fire

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UNLOCK_PANEL_BG
	style.border_color = UNLOCK_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var heading := Label.new()
	heading.text = "🎉  New line unlocked!" if ids.size() == 1 else "🎉  New lines unlocked!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", UNLOCK_GOLD)
	vbox.add_child(heading)

	for id in ids:
		var p: Dictionary = ShiftScript.PRODUCTS.get(id, {})
		var name_lbl := Label.new()
		name_lbl.text = "★  %s" % p.get("label", String(id))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(name_lbl)
		var blurb: String = p.get("unlock_blurb", "")
		if blurb != "":
			var blurb_lbl := Label.new()
			blurb_lbl.text = blurb
			blurb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			blurb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			blurb_lbl.custom_minimum_size = Vector2(420, 0)
			blurb_lbl.modulate = Color(1, 1, 1, 0.8)
			vbox.add_child(blurb_lbl)

	var dismiss := Label.new()
	dismiss.text = "(click to dismiss)"
	dismiss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dismiss.add_theme_font_size_override("font_size", 11)
	dismiss.modulate = Color(1, 1, 1, 0.5)
	vbox.add_child(dismiss)

	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			panel.queue_free())
	add_child(panel)
	get_tree().create_timer(7.0).timeout.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free())


func _refresh_hud() -> void:
	_day_label.text = "Day %d" % GameState.day
	_money_label.text = "%d kr" % GameState.money
	# Trustpilot-style rating: Unrated until the first review, then a star row + the
	# exact decimal + the review count (StoreRating owns the formatting).
	_reputation_label.text = StoreRating.summary(GameState.review_points, GameState.review_count)
	_phase_label.text = DayCycle.phase_name()
