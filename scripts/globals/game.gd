extends Node
## Game — top-level application controller.
##
## A thin layer for app-wide concerns: version info, boot-time setup, and global
## helpers like quitting. Game-rules state lives in GameState; the day loop lives
## in DayCycle. Keep this script small.

const VERSION := "0.0.1"  ## v1 prototype

const OfflineEarningsScript := preload("res://scripts/offline_earnings.gd")

## The last computed days-away catch-up, {days, reward}, or {} if none. Set once
## on boot; Main reads it to show a one-time "welcome back" banner. Transient —
## not part of the save.
var last_offline_report: Dictionary = {}


func _ready() -> void:
	# Load a previous save if one exists so day/money/stock carry over; otherwise
	# GameState keeps its fresh defaults. This runs before the Main scene starts
	# (autoloads are ready first), so the first phase opens with correct values.
	if GameState.has_save():
		GameState.load_game()
	else:
		GameState.reset()
	_grant_offline_earnings()


## Grant the days-away catch-up reward for the gap between the loaded save's
## timestamp and now (issue #6). Purely positive and bounded; a fresh game or a
## sub-day gap grants nothing. When a reward is granted we persist immediately so
## the same gap can't be re-granted on the next launch (it resets last_saved_unix).
func _grant_offline_earnings() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	last_offline_report = OfflineEarningsScript.compute(GameState.last_saved_unix, now)
	var reward: int = int(last_offline_report["reward"])
	if reward > 0:
		GameState.money += reward
		GameState.save_game()


func quit_game() -> void:
	get_tree().quit()
