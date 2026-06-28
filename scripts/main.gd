extends Control
## Main — the root scene. Shows a minimal HUD (day / money / phase) and hosts the
## current phase's screen, swapping it whenever DayCycle reports a phase change.
## This is the visible proof that the day loop is wired end to end.

const StoreRating := preload("res://scripts/store_rating.gd")

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


func _refresh_hud() -> void:
	_day_label.text = "Day %d" % GameState.day
	_money_label.text = "%d kr" % GameState.money
	# Trustpilot-style rating: Unrated until the first review, then a star row + the
	# exact decimal + the review count (StoreRating owns the formatting).
	_reputation_label.text = StoreRating.summary(GameState.review_points, GameState.review_count)
	_phase_label.text = DayCycle.phase_name()
