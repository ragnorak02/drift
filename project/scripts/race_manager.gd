extends Node2D

## Main race scene orchestrator.
## Wires up 2 cars, track, lap managers, overhead camera, and UI.

@onready var car: CharacterBody2D = $CarPlayer
@onready var car2: CharacterBody2D = $CarPlayer2
@onready var track: Node2D = $Track
@onready var lap_manager: Node = $LapManager
@onready var lap_manager2: Node = $LapManager2
@onready var ui: CanvasLayer = $UI

var _race_winner: int = 0  # 0 = no winner yet, 1 or 2

func _ready() -> void:
	# Wire UI references
	ui.car = car
	ui.car2 = car2
	ui.lap_manager = lap_manager
	ui.lap_manager2 = lap_manager2

	# Wire track checkpoints to both lap managers with car filtering
	track.connect_to_lap_manager(lap_manager, car)
	track.connect_to_lap_manager(lap_manager2, car2)

	# Connect race finished signals
	lap_manager.race_finished.connect(_on_race_finished.bind(1))
	lap_manager2.race_finished.connect(_on_race_finished.bind(2))

	# Connect missile signals
	car.missile_fired.connect(_on_missile_fired)
	car2.missile_fired.connect(_on_missile_fired)

	# Hide the unused ScreenLayout from split-screen era
	$ScreenLayout.visible = false

	# Set up overhead camera showing entire track
	_setup_overhead_camera()

	# Start countdown then race
	_start_race_sequence()

func _setup_overhead_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "OverheadCamera"
	# Center of track bounding box (~350-5950 x ~150-4200)
	cam.position = Vector2(3150, 2175)
	# Zoom to fit entire track: min(1280/5600, 720/4050) * 0.9 margin ≈ 0.16
	cam.zoom = Vector2(0.16, 0.16)
	cam.enabled = true
	add_child(cam)

func _start_race_sequence() -> void:
	car.race_started = false
	car2.race_started = false
	await ui.show_countdown()
	car.start_race()
	car2.start_race()
	lap_manager.start_race()
	lap_manager2.start_race()

func _on_race_finished(total_time: float, best_lap: float, player_id: int) -> void:
	if _race_winner == 0:
		_race_winner = player_id
		# Stop both cars
		car.stop_race()
		car2.stop_race()
		ui.show_race_complete_2p(_race_winner, lap_manager, lap_manager2)

func _on_missile_fired(spawn_pos: Vector2, direction: Vector2, source_car: CharacterBody2D) -> void:
	var missile_script := load("res://scripts/missile.gd")
	var missile := Area2D.new()
	missile.set_script(missile_script)
	missile.global_position = spawn_pos
	missile.set("direction", direction)
	missile.set("source_car", source_car)
	# Target the other car
	if source_car == car:
		missile.set("target_car", car2)
	else:
		missile.set("target_car", car)
	add_child(missile)
