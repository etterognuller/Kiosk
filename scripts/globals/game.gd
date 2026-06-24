extends Node
## Game — top-level application controller.
##
## A thin layer for app-wide concerns: version info, boot-time setup, and global
## helpers like quitting. Game-rules state lives in GameState; the day loop lives
## in DayCycle. Keep this script small.

const VERSION := "0.0.1"  ## v1 prototype


func _ready() -> void:
	# Load a previous save if one exists so day/money/stock carry over; otherwise
	# GameState keeps its fresh defaults. This runs before the Main scene starts
	# (autoloads are ready first), so the first phase opens with correct values.
	if GameState.has_save():
		GameState.load_game()
	else:
		GameState.reset()


func quit_game() -> void:
	get_tree().quit()
