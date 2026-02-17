extends Node2D

## Main race scene orchestrator.
## Wires up car, track, lap manager, and UI.

@onready var car: CharacterBody2D = $CarPlayer
@onready var track: Node2D = $Track
@onready var lap_manager: Node = $LapManager
@onready var ui: CanvasLayer = $UI
@onready var camera: Camera2D = $RaceCamera

func _ready() -> void:
	# Wire UI references
	ui.car = car
	ui.lap_manager = lap_manager

	# Let track wire its checkpoints/finish to the lap manager
	track.connect_to_lap_manager(lap_manager)

	# Connect lap manager signals to UI
	lap_manager.race_finished.connect(_on_race_finished)

	# Start countdown then race
	_start_race_sequence()

func _start_race_sequence() -> void:
	car.race_started = false
	await ui.show_countdown()
	car.start_race()
	lap_manager.start_race()

func _on_race_finished(total_time: float, best_lap: float) -> void:
	car.stop_race()
	ui.show_race_complete(total_time, best_lap)
