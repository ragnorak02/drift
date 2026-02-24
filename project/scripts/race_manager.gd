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
var _overhead_camera: Camera2D = null
var _player_count: int = 2

func _ready() -> void:
	# Read player count from main menu
	var menu_script = load("res://scripts/main_menu.gd")
	if menu_script and "player_count" in menu_script:
		_player_count = menu_script.player_count

	# Position cars at track start line
	_position_cars_at_start()

	if _player_count == 2:
		# -- 2-Player mode --
		# Attach AI controller to P2
		car2.ai_controlled = true
		var ai := preload("res://scripts/ai_controller.gd").new()
		car2.add_child(ai)

		# Wire UI references
		ui.car = car
		ui.car2 = car2
		ui.lap_manager = lap_manager
		ui.lap_manager2 = lap_manager2

		# Wire track checkpoints to both lap managers
		track.connect_to_lap_manager(lap_manager, car)
		track.connect_to_lap_manager(lap_manager2, car2)

		# Connect race finished signals
		lap_manager.race_finished.connect(_on_race_finished.bind(1))
		lap_manager2.race_finished.connect(_on_race_finished.bind(2))

		# Wire targeting opponents
		car.set_target_car(car2)
		car2.set_target_car(car)

		# Connect missile signals
		car.missile_fired.connect(_on_missile_fired)
		car2.missile_fired.connect(_on_missile_fired)

		# Connect drift boost signals for screen shake
		car.drift_released.connect(_on_drift_boost_released)
		car2.drift_released.connect(_on_drift_boost_released)

		# Achievement system wiring
		AchievementManager.clear_callbacks()
		AchievementManager.register_unlock_callback(ui.show_achievement_toast)
		lap_manager.lap_completed.connect(_on_achievement_lap_completed)
		lap_manager2.lap_completed.connect(_on_achievement_lap_completed)
		car.speed_changed.connect(_on_achievement_speed_check)
		car2.speed_changed.connect(_on_achievement_speed_check)
		car.drift_released.connect(_on_achievement_drift_check.bind(car))
		car2.drift_released.connect(_on_achievement_drift_check.bind(car2))
	else:
		# -- 1-Player mode --
		# Hide and disable P2 car
		car2.visible = false
		car2.process_mode = Node.PROCESS_MODE_DISABLED

		# Wire UI references (P2 = null)
		ui.car = car
		ui.car2 = null
		ui.lap_manager = lap_manager
		ui.lap_manager2 = null
		ui.hide_p2_hud()

		# Wire track checkpoints for P1 only
		track.connect_to_lap_manager(lap_manager, car)

		# Connect race finished signal for P1 only
		lap_manager.race_finished.connect(_on_race_finished.bind(1))

		# No targeting in single-player
		car.set_target_car(null)

		# Connect missile + drift signals for P1 only
		car.missile_fired.connect(_on_missile_fired)
		car.drift_released.connect(_on_drift_boost_released)

		# Achievement system wiring (P1 only)
		AchievementManager.clear_callbacks()
		AchievementManager.register_unlock_callback(ui.show_achievement_toast)
		lap_manager.lap_completed.connect(_on_achievement_lap_completed)
		car.speed_changed.connect(_on_achievement_speed_check)
		car.drift_released.connect(_on_achievement_drift_check.bind(car))

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

	if _player_count == 1:
		# Single-player: P1 at center of start line
		car.global_position = start
		car.rotation = race_rotation
		car.spawn_position = car.global_position
		car.spawn_rotation = car.rotation
	else:
		# 2-player: P1 slightly left, P2 slightly right
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
	_overhead_camera = cam
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
	if _player_count == 2:
		car2.race_started = false
	await ui.show_countdown()
	print("[Race] Race started — %d player(s)" % _player_count)
	car.start_race()
	lap_manager.start_race()
	if _player_count == 2:
		car2.start_race()
		lap_manager2.start_race()
	# Track connected controllers after race starts (avoids false triggers during init)
	for device_id in Input.get_connected_joypads():
		_connected_devices.append(device_id)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_race_finished(total_time: float, best_lap: float, player_id: int) -> void:
	if _race_winner == 0:
		_race_winner = player_id
		car.stop_race()

		if _player_count == 1:
			# -- Single-player race end --
			print("[Race] Race complete! Total: %.2fs, Best lap: %.2fs" % [total_time, best_lap])
			var p1_pb := LapHistory.save_race(1, track.track_index, lap_manager.total_race_time, lap_manager.best_lap_time, Array(lap_manager.lap_times), true)

			AchievementManager.try_unlock("first_race")
			if car.wall_hit_count == 0:
				AchievementManager.try_unlock("clean_run")
			if p1_pb.get("new_best_lap", false) and p1_pb.get("prev_best_lap", INF) != INF:
				AchievementManager.try_unlock("personal_best")
			if LapHistory.get_total_race_count() >= 10:
				AchievementManager.try_unlock("track_master")

			ui.show_race_complete(total_time, best_lap)
		else:
			# -- 2-Player race end --
			print("[Race] P%d wins! Total: %.2fs, Best lap: %.2fs" % [player_id, total_time, best_lap])
			car2.stop_race()

			var p1_won := (_race_winner == 1)
			var p1_pb := LapHistory.save_race(1, track.track_index, lap_manager.total_race_time, lap_manager.best_lap_time, Array(lap_manager.lap_times), p1_won)
			var p2_won := (_race_winner == 2)
			var p2_pb := LapHistory.save_race(2, track.track_index, lap_manager2.total_race_time, lap_manager2.best_lap_time, Array(lap_manager2.lap_times), p2_won)

			AchievementManager.try_unlock("first_race")

			var winner_car := car if _race_winner == 1 else car2
			if winner_car.wall_hit_count == 0:
				AchievementManager.try_unlock("clean_run")

			if p1_pb.get("new_best_lap", false) and p1_pb.get("prev_best_lap", INF) != INF:
				AchievementManager.try_unlock("personal_best")
			if p2_pb.get("new_best_lap", false) and p2_pb.get("prev_best_lap", INF) != INF:
				AchievementManager.try_unlock("personal_best")

			if LapHistory.get_total_race_count() >= 10:
				AchievementManager.try_unlock("track_master")

			ui.show_race_complete_2p(_race_winner, lap_manager, lap_manager2, p1_pb, p2_pb)

func _on_missile_fired(spawn_pos: Vector2, direction: Vector2, source_car: CharacterBody2D, locked: bool) -> void:
	var missile_script := load("res://scripts/missile.gd")
	var missile := Area2D.new()
	missile.set_script(missile_script)
	missile.global_position = spawn_pos
	missile.set("direction", direction)
	missile.set("source_car", source_car)
	# Only home on opponent when locked; otherwise flies straight
	if locked and _player_count == 2:
		if source_car == car:
			missile.set("target_car", car2)
		else:
			missile.set("target_car", car)
	else:
		missile.set("target_car", null)
	add_child(missile)

func _on_drift_boost_released(boost_strength: float) -> void:
	if not _overhead_camera:
		return
	# Scale shake intensity by boost strength (normalized to max boost)
	var intensity := clampf(boost_strength / GameConstants.DRIFT_BOOST_MAX, 0.2, 1.0) * 6.0
	var tw := create_tween()
	tw.tween_property(_overhead_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.04)
	tw.tween_property(_overhead_camera, "offset", Vector2(randf_range(-intensity * 0.6, intensity * 0.6), randf_range(-intensity * 0.6, intensity * 0.6)), 0.04)
	tw.tween_property(_overhead_camera, "offset", Vector2(randf_range(-intensity * 0.3, intensity * 0.3), randf_range(-intensity * 0.3, intensity * 0.3)), 0.04)
	tw.tween_property(_overhead_camera, "offset", Vector2.ZERO, 0.06)

func _on_achievement_lap_completed(_lap_number: int, _lap_time: float) -> void:
	AchievementManager.try_unlock("first_lap")
	AchievementManager.try_unlock("checkpoint_ace")

func _on_achievement_speed_check(speed: float) -> void:
	if speed >= GameConstants.CAR_MAX_SPEED:
		AchievementManager.try_unlock("speed_demon")

func _on_achievement_drift_check(_boost_strength: float, source_car: CharacterBody2D) -> void:
	if source_car.drift_charge_time >= 3.0:
		AchievementManager.try_unlock("drift_king")

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
