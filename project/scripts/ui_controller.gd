extends CanvasLayer

# References set via Main.tscn wiring
var car: CharacterBody2D = null
var lap_manager: Node = null

# UI nodes (found in _ready)
@onready var lap_label: Label = %LapLabel
@onready var time_label: Label = %TimeLabel
@onready var best_label: Label = %BestLabel
@onready var speed_label: Label = %SpeedLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var item_indicator: Label = %ItemIndicator
@onready var debug_overlay: VBoxContainer = %DebugOverlay
@onready var debug_speed: Label = %DebugSpeed
@onready var debug_drift: Label = %DebugDrift
@onready var debug_grip: Label = %DebugGrip
@onready var debug_steer: Label = %DebugSteer
@onready var pause_menu: CenterContainer = %PauseMenu
@onready var race_complete_panel: CenterContainer = %RaceCompletePanel
@onready var race_total_time: Label = %RaceTotalTime
@onready var race_best_lap: Label = %RaceBestLap

var is_paused: bool = false
var debug_visible: bool = false

func _ready() -> void:
	debug_overlay.visible = false
	pause_menu.visible = false
	race_complete_panel.visible = false
	countdown_label.visible = false

func _process(_delta: float) -> void:
	if car and lap_manager:
		_update_hud()
		if debug_visible:
			_update_debug()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("debug_toggle"):
		debug_visible = not debug_visible
		debug_overlay.visible = debug_visible
		get_viewport().set_input_as_handled()

func _update_hud() -> void:
	if lap_manager:
		lap_label.text = "LAP %d/%d" % [lap_manager.current_lap, lap_manager.total_laps]
		time_label.text = lap_manager.format_time(lap_manager.current_lap_time)
		best_label.text = "BEST: " + lap_manager.format_time(lap_manager.best_lap_time)

	if car:
		speed_label.text = "%d km/h" % int(car.current_speed * 0.5)
		if car.has_item:
			item_indicator.text = "BOOST READY [B/E]"
		elif car.item_boost_active:
			item_indicator.text = "BOOSTING!"
		else:
			item_indicator.text = ""

func _update_debug() -> void:
	if not car:
		return
	debug_speed.text = "Speed: %.1f" % car.current_speed
	var state := "BOOST!" if (not car.jump_held and car.drift_time > 0) else ("DRIFT %.1fs" % car.drift_time if car.is_drifting else ("JUMP" if car.is_jumping else "---"))
	debug_drift.text = "State: %s" % state
	debug_grip.text = "Traction: %.2f" % car.current_traction
	debug_steer.text = "Steer: %.2f (%s)" % [car.steer_input, "mouse" if car.use_mouse_steer else "stick/kb"]

func _toggle_pause() -> void:
	if lap_manager and lap_manager.race_complete:
		return
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused
	if is_paused:
		# Grab focus on Resume button for controller navigation
		var resume_btn := pause_menu.find_child("ResumeButton")
		if resume_btn:
			resume_btn.grab_focus()

func show_countdown() -> void:
	countdown_label.visible = true
	countdown_label.text = "3"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "2"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "1"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5).timeout
	countdown_label.visible = false

func show_race_complete(total_time: float, best_lap: float) -> void:
	race_complete_panel.visible = true
	race_total_time.text = "Total: " + lap_manager.format_time(total_time)
	race_best_lap.text = "Best Lap: " + lap_manager.format_time(best_lap)
	var restart_btn := race_complete_panel.find_child("RaceRestartButton")
	if restart_btn:
		restart_btn.grab_focus()

# -- Pause menu button handlers --
func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# -- Race complete button handlers --
func _on_race_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_race_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
