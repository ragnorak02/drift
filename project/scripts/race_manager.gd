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
var _connected_devices: Array[int] = []
var _controller_paused: bool = false

func _ready() -> void:
	# Position cars at track start line
	_position_cars_at_start()

	# Attach AI controller to P2
	car2.ai_controlled = true
	var ai := preload("res://scripts/ai_controller.gd").new()
	car2.add_child(ai)

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

func _position_cars_at_start() -> void:
	if track.centerline.size() < 2:
		return
	var start: Vector2 = track.centerline[0]
	var next: Vector2 = track.centerline[1]
	var dir: Vector2 = (next - start).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var race_rotation: float = dir.angle() + PI / 2.0
	# P1 slightly left of center, P2 slightly right
	car.global_position = start + perp * -100
	car.rotation = race_rotation
	car.spawn_position = car.global_position
	car.spawn_rotation = car.rotation
	car2.global_position = start + perp * 100
	car2.rotation = race_rotation
	car2.spawn_position = car2.global_position
	car2.spawn_rotation = car2.rotation

func _setup_overhead_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "OverheadCamera"
	# Compute camera from track bounding box
	var bbox: Rect2 = track.get_bounding_box()
	cam.position = bbox.position + bbox.size * 0.5
	var viewport_size: Vector2 = Vector2(1280, 720)
	var zoom_x: float = viewport_size.x / (bbox.size.x + 600)
	var zoom_y: float = viewport_size.y / (bbox.size.y + 600)
	var zoom_val := minf(zoom_x, zoom_y) * 0.9 + SettingsManager.camera_zoom_offset
	cam.zoom = Vector2(zoom_val, zoom_val)
	cam.enabled = true
	add_child(cam)

func _start_race_sequence() -> void:
	car.race_started = false
	car2.race_started = false
	await ui.show_countdown()
	print("[Race] Race started — 2 players")
	car.start_race()
	car2.start_race()
	lap_manager.start_race()
	lap_manager2.start_race()
	# Track connected controllers after race starts (avoids false triggers during init)
	for device_id in Input.get_connected_joypads():
		_connected_devices.append(device_id)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_race_finished(total_time: float, best_lap: float, player_id: int) -> void:
	if _race_winner == 0:
		print("[Race] P%d wins! Total: %.2fs, Best lap: %.2fs" % [player_id, total_time, best_lap])
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

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		print("[Input] Controller %d reconnected" % device_id)
		if _controller_paused and device_id in _connected_devices:
			# All originally-connected devices back? Resume
			var all_back := true
			for dev in _connected_devices:
				if dev not in Input.get_connected_joypads():
					all_back = false
					break
			if all_back:
				_controller_paused = false
				get_tree().paused = false
				ui.hide_controller_disconnect()
	else:
		# Only pause if this device was connected at race start
		if device_id in _connected_devices:
			print("[Input] Controller %d disconnected during race" % device_id)
			if not _controller_paused and not get_tree().paused:
				_controller_paused = true
				get_tree().paused = true
				ui.show_controller_disconnect()
