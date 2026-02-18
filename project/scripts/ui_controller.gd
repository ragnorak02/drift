extends CanvasLayer

# References set via race_manager wiring
var car: CharacterBody2D = null
var car2: CharacterBody2D = null
var lap_manager: Node = null
var lap_manager2: Node = null

# P1 HUD nodes
@onready var lap_label: Label = %LapLabel
@onready var time_label: Label = %TimeLabel
@onready var best_label: Label = %BestLabel
@onready var speed_label: Label = %SpeedLabel
@onready var item_indicator: Label = %ItemIndicator
@onready var missile_indicator: Label = %MissileIndicator

# P2 HUD nodes
@onready var p2_lap_label: Label = %P2LapLabel
@onready var p2_time_label: Label = %P2TimeLabel
@onready var p2_best_label: Label = %P2BestLabel
@onready var p2_speed_label: Label = %P2SpeedLabel
@onready var p2_item_indicator: Label = %P2ItemIndicator
@onready var p2_missile_indicator: Label = %P2MissileIndicator

@onready var countdown_label: Label = %CountdownLabel
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
	# P1 HUD
	if lap_manager:
		lap_label.text = "LAP %d/%d" % [lap_manager.current_lap, lap_manager.total_laps]
		time_label.text = lap_manager.format_time(lap_manager.current_lap_time)
		best_label.text = "BEST: " + lap_manager.format_time(lap_manager.best_lap_time)

	if car:
		speed_label.text = "%d km/h" % int(car.current_speed * 0.5)
		if car.has_item:
			item_indicator.text = "BOOST [E]"
		elif car.item_boost_active:
			item_indicator.text = "BOOSTING!"
		else:
			item_indicator.text = ""
		missile_indicator.text = "MSL: %d" % car.missile_count if car.missile_count > 0 else ""

	# P2 HUD
	if lap_manager2:
		p2_lap_label.text = "LAP %d/%d" % [lap_manager2.current_lap, lap_manager2.total_laps]
		p2_time_label.text = lap_manager2.format_time(lap_manager2.current_lap_time)
		p2_best_label.text = "BEST: " + lap_manager2.format_time(lap_manager2.best_lap_time)

	if car2:
		p2_speed_label.text = "%d km/h" % int(car2.current_speed * 0.5)
		if car2.has_item:
			p2_item_indicator.text = "BOOST [NpEnter]"
		elif car2.item_boost_active:
			p2_item_indicator.text = "BOOSTING!"
		else:
			p2_item_indicator.text = ""
		p2_missile_indicator.text = "MSL: %d" % car2.missile_count if car2.missile_count > 0 else ""

func _update_debug() -> void:
	if not car:
		return
	debug_speed.text = "Speed: %.1f" % car.current_speed
	var state := "---"
	if car.hit_stun_timer > 0.0:
		state = "STUNNED %.1fs" % car.hit_stun_timer
	elif car.jump_airborne:
		state = "AIRBORNE"
	elif car.is_drift_sliding:
		state = "DRIFT %.1fs (%d%%)" % [car.drift_charge_time, int(car.drift_charge_ratio * 100)]
	elif car.is_boosting:
		state = "BOOST!"
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

func show_race_complete_2p(winner: int, lm1: Node, lm2: Node) -> void:
	race_complete_panel.visible = true
	var winner_text := "P1 WINS!" if winner == 1 else "P2 WINS!"
	# Reuse existing labels for 2P display
	var title_label := race_complete_panel.find_child("CompleteTitle")
	if title_label:
		title_label.text = winner_text
	race_total_time.text = "P1: %s | P2: %s" % [lm1.format_time(lm1.total_race_time), lm2.format_time(lm2.total_race_time)]
	race_best_lap.text = "Best — P1: %s | P2: %s" % [lm1.format_time(lm1.best_lap_time), lm2.format_time(lm2.best_lap_time)]
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
