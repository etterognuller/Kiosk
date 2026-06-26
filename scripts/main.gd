extends Control
## Main — the root scene. Shows a minimal HUD (day / money / phase) and hosts the
## current phase's screen, swapping it whenever DayCycle reports a phase change.
## This is the visible proof that the day loop is wired end to end.

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
	DayCycle.start()


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
	_reputation_label.text = "Rep %d" % GameState.reputation
	_phase_label.text = DayCycle.phase_name()
