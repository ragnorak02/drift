extends Node2D

## Main race scene orchestrator.
## Wires up 2 cars, track, lap managers, split-screen cameras, and UI.

@onready var car: CharacterBody2D = $CarPlayer
@onready var car2: CharacterBody2D = $CarPlayer2
@onready var track: Node2D = $Track
@onready var lap_manager: Node = $LapManager
@onready var lap_manager2: Node = $LapManager2
@onready var ui: CanvasLayer = $UI

# Split-screen viewport refs (set up in _ready)
var _viewport_p1: SubViewport = null
var _viewport_p2: SubViewport = null
var _camera_p1: Camera2D = null
var _camera_p2: Camera2D = null

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

	# Set up split-screen
	_setup_split_screen()

	# Start countdown then race
	_start_race_sequence()

func _setup_split_screen() -> void:
	var screen_layout: Control = $ScreenLayout
	var vbox: VBoxContainer = screen_layout.get_node("VBox")

	# P1 viewport
	var container_p1 := SubViewportContainer.new()
	container_p1.name = "SubViewportContainerP1"
	container_p1.custom_minimum_size = Vector2(1280, 356)
	container_p1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container_p1.stretch = true
	vbox.add_child(container_p1)

	_viewport_p1 = SubViewport.new()
	_viewport_p1.name = "SubViewportP1"
	_viewport_p1.size = Vector2i(1280, 356)
	_viewport_p1.handle_input_locally = false
	_viewport_p1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container_p1.add_child(_viewport_p1)

	_camera_p1 = Camera2D.new()
	_camera_p1.name = "CameraP1"
	var cam_script := load("res://scripts/camera_follow.gd")
	_camera_p1.set_script(cam_script)
	_viewport_p1.add_child(_camera_p1)

	# Gold divider
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.custom_minimum_size = Vector2(1280, 4)
	divider.color = Color(0.941, 0.784, 0.314, 1)
	vbox.add_child(divider)

	# P2 viewport
	var container_p2 := SubViewportContainer.new()
	container_p2.name = "SubViewportContainerP2"
	container_p2.custom_minimum_size = Vector2(1280, 356)
	container_p2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container_p2.stretch = true
	vbox.add_child(container_p2)

	_viewport_p2 = SubViewport.new()
	_viewport_p2.name = "SubViewportP2"
	_viewport_p2.size = Vector2i(1280, 356)
	_viewport_p2.handle_input_locally = false
	_viewport_p2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container_p2.add_child(_viewport_p2)

	_camera_p2 = Camera2D.new()
	_camera_p2.name = "CameraP2"
	_camera_p2.set_script(cam_script)
	_viewport_p2.add_child(_camera_p2)

	# Share the main world_2d so both viewports see game objects
	_viewport_p1.world_2d = get_viewport().world_2d
	_viewport_p2.world_2d = get_viewport().world_2d

	# Wire camera targets
	_camera_p1.set_target(car)
	_camera_p2.set_target(car2)

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
