extends Control
## PhaseStub — a placeholder screen shared by all three v1 phases (Procure, Serve,
## Upgrade). Each phase scene sets the exported text below; the single button just
## advances the day loop. Replace these stubs with real gameplay one phase at a
## time as v1 is built out.

@export var title: String = "Phase"
@export_multiline var hint: String = ""
@export var button_label: String = "Continue →"

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _button: Button = %AdvanceButton


func _ready() -> void:
	_title.text = title
	_hint.text = hint
	_button.text = button_label
	_button.pressed.connect(_on_advance_pressed)


func _on_advance_pressed() -> void:
	DayCycle.advance()
