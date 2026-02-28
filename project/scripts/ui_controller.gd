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

# Achievement toast system
var _achievement_toast_queue: Array[Dictionary] = []
var _achievement_toast_active: bool = false

var _version_label: Label = null
var _drift_bar_bg: ColorRect = null
var _drift_bar_fill: ColorRect = null
var _p2_drift_bar_bg: ColorRect = null
var _p2_drift_bar_fill: ColorRect = null

func _ready() -> void:
	debug_overlay.visible = false
	pause_menu.visible = false
	race_complete_panel.visible = false
	countdown_label.visible = false
	_create_version_label()
	_create_drift_bars()
	_add_hud_backgrounds()
	_apply_gold_focus_to_buttons()

func _create_version_label() -> void:
	_version_label = Label.new()
	_version_label.text = "v%s" % GameConstants.VERSION
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_version_label.anchor_left = 1.0
	_version_label.anchor_top = 1.0
	_version_label.anchor_right = 1.0
	_version_label.anchor_bottom = 1.0
	_version_label.offset_left = -80.0
	_version_label.offset_top = -25.0
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_version_label)

func _create_drift_bars() -> void:
	# P1 drift charge bar — below P1 HUD
	_drift_bar_bg = ColorRect.new()
	_drift_bar_bg.color = Color(0.2, 0.2, 0.2, 0.5)
	_drift_bar_bg.custom_minimum_size = Vector2(120, 6)
	_drift_bar_bg.size = Vector2(120, 6)
	_drift_bar_bg.anchors_preset = Control.PRESET_TOP_LEFT
	_drift_bar_bg.position = Vector2(10, 52)
	_drift_bar_bg.visible = false
	add_child(_drift_bar_bg)

	_drift_bar_fill = ColorRect.new()
	_drift_bar_fill.color = Color(1.0, 0.55, 0.0, 0.9)
	_drift_bar_fill.size = Vector2(0, 6)
	_drift_bar_fill.position = Vector2.ZERO
	_drift_bar_bg.add_child(_drift_bar_fill)

	# P2 drift charge bar — above P2 HUD
	_p2_drift_bar_bg = ColorRect.new()
	_p2_drift_bar_bg.color = Color(0.2, 0.2, 0.2, 0.5)
	_p2_drift_bar_bg.custom_minimum_size = Vector2(120, 6)
	_p2_drift_bar_bg.size = Vector2(120, 6)
	_p2_drift_bar_bg.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_p2_drift_bar_bg.anchor_top = 1.0
	_p2_drift_bar_bg.anchor_bottom = 1.0
	_p2_drift_bar_bg.position = Vector2(10, -118)
	_p2_drift_bar_bg.visible = false
	add_child(_p2_drift_bar_bg)

	_p2_drift_bar_fill = ColorRect.new()
	_p2_drift_bar_fill.color = Color(1.0, 0.55, 0.0, 0.9)
	_p2_drift_bar_fill.size = Vector2(0, 6)
	_p2_drift_bar_fill.position = Vector2.ZERO
	_p2_drift_bar_bg.add_child(_p2_drift_bar_fill)

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
			item_indicator.add_theme_color_override("font_color", Color(0, 1, 0.5, 0.9))
		elif car.item_boost_active:
			item_indicator.text = "BOOSTING!"
			item_indicator.add_theme_color_override("font_color", Color(0, 1, 0.5, 0.9))
		else:
			item_indicator.text = "---"
			item_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.4))
		if car.targeting_state != car.TargetingState.IDLE:
			if car._reticle_locked:
				missile_indicator.text = "LOCKED"
				missile_indicator.add_theme_color_override("font_color", Color(0.1, 1.0, 0.2, 0.9))
			else:
				var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
				missile_indicator.text = "TARGETING"
				missile_indicator.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0, pulse))
		elif car.missile_count > 0:
			missile_indicator.text = "MSL: %d" % car.missile_count
			missile_indicator.add_theme_color_override("font_color", Color(1, 0.3, 0.1, 0.9))
		else:
			missile_indicator.text = "---"
			missile_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.4))

	# P1 Drift charge bar
	if car:
		_update_drift_bar(car, _drift_bar_bg, _drift_bar_fill)

	# P2 HUD
	if lap_manager2:
		p2_lap_label.text = "LAP %d/%d" % [lap_manager2.current_lap, lap_manager2.total_laps]
		p2_time_label.text = lap_manager2.format_time(lap_manager2.current_lap_time)
		p2_best_label.text = "BEST: " + lap_manager2.format_time(lap_manager2.best_lap_time)

	if car2:
		p2_speed_label.text = "%d km/h" % int(car2.current_speed * 0.5)
		if car2.has_item:
			p2_item_indicator.text = "BOOST [NpEnter]"
			p2_item_indicator.add_theme_color_override("font_color", Color(0, 1, 0.5, 0.9))
		elif car2.item_boost_active:
			p2_item_indicator.text = "BOOSTING!"
			p2_item_indicator.add_theme_color_override("font_color", Color(0, 1, 0.5, 0.9))
		else:
			p2_item_indicator.text = "---"
			p2_item_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.4))
		if car2.targeting_state != car2.TargetingState.IDLE:
			if car2._reticle_locked:
				p2_missile_indicator.text = "LOCKED"
				p2_missile_indicator.add_theme_color_override("font_color", Color(0.1, 1.0, 0.2, 0.9))
			else:
				var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
				p2_missile_indicator.text = "TARGETING"
				p2_missile_indicator.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0, pulse))
		elif car2.missile_count > 0:
			p2_missile_indicator.text = "MSL: %d" % car2.missile_count
			p2_missile_indicator.add_theme_color_override("font_color", Color(1, 0.3, 0.1, 0.9))
		else:
			p2_missile_indicator.text = "---"
			p2_missile_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.4))

	# P2 Drift charge bar
	if car2:
		_update_drift_bar(car2, _p2_drift_bar_bg, _p2_drift_bar_fill)

func _update_drift_bar(c: CharacterBody2D, bg: ColorRect, fill: ColorRect) -> void:
	if c.is_drift_sliding and c.drift_charge_ratio > 0.0:
		bg.visible = true
		fill.size.x = c.drift_charge_ratio * bg.size.x
		# Color by tier
		match c.drift_tier:
			0:
				fill.color = Color(0.5, 0.5, 0.5, 0.7)
			1:
				fill.color = Color(1.0, 0.55, 0.0, 0.9)
			2:
				fill.color = Color(1.0, 0.15, 0.0, 0.9)
			3:
				fill.color = Color(0.7, 0.2, 1.0, 0.9)
			_:
				fill.color = Color(0.5, 0.5, 0.5, 0.7)
	else:
		bg.visible = false
		fill.size.x = 0.0

func _update_debug() -> void:
	if not car:
		return
	debug_speed.text = "Speed: %.1f" % car.current_speed
	var state := "---"
	if car.hit_stun_timer > 0.0:
		state = "STUNNED %.1fs" % car.hit_stun_timer
	elif car.is_drift_sliding:
		state = "DRIFT T%d %.1fs (%d%%)" % [car.drift_tier, car.drift_charge_time, int(car.drift_charge_ratio * 100)]
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
	for num in ["3", "2", "1"]:
		countdown_label.text = num
		AudioManager.play_countdown_beep(false)
		# Scale-pulse: start big, settle to normal
		countdown_label.scale = Vector2(1.5, 1.5)
		countdown_label.pivot_offset = countdown_label.size * 0.5
		var tw := create_tween()
		tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.4)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(1.0).timeout
	countdown_label.text = "GO!"
	AudioManager.play_countdown_beep(true)
	countdown_label.scale = Vector2(1.5, 1.5)
	var go_tw := create_tween()
	go_tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(0.5).timeout
	countdown_label.visible = false
	countdown_label.scale = Vector2.ONE

func show_race_complete(total_time: float, best_lap: float) -> void:
	race_complete_panel.visible = true
	race_total_time.text = "Total: " + lap_manager.format_time(total_time)
	race_best_lap.text = "Best Lap: " + lap_manager.format_time(best_lap)
	var restart_btn := race_complete_panel.find_child("RaceRestartButton")
	if restart_btn:
		restart_btn.grab_focus()

func show_race_complete_2p(winner: int, lm1: Node, lm2: Node, p1_pb: Dictionary = {}, p2_pb: Dictionary = {}) -> void:
	race_complete_panel.visible = true
	var winner_text := "P1 WINS!" if winner == 1 else "P2 WINS!"
	var title_label := race_complete_panel.find_child("CompleteTitle")
	if title_label:
		title_label.text = winner_text
		# Gold pulse animation on winner text
		var tw := create_tween().set_loops()
		tw.tween_property(title_label, "theme_override_colors/font_color",
			Color(1, 1, 0.6, 1), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(title_label, "theme_override_colors/font_color",
			Color(0.941, 0.784, 0.314, 1), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	race_total_time.text = "P1: %s | P2: %s" % [lm1.format_time(lm1.total_race_time), lm2.format_time(lm2.total_race_time)]
	race_best_lap.text = "Best — P1: %s | P2: %s" % [lm1.format_time(lm1.best_lap_time), lm2.format_time(lm2.best_lap_time)]

	# PB indicators
	_add_pb_labels(p1_pb, p2_pb, lm1)

	var restart_btn := race_complete_panel.find_child("RaceRestartButton")
	if restart_btn:
		restart_btn.grab_focus()

func _add_pb_labels(p1_pb: Dictionary, p2_pb: Dictionary, lm: Node) -> void:
	# Clean up any existing PB labels from previous race
	var vbox := race_complete_panel.find_child("VBox")
	if not vbox:
		return
	for child in vbox.get_children():
		if child.has_meta("pb_label"):
			child.queue_free()

	if p1_pb.is_empty() and p2_pb.is_empty():
		return

	# Build PB announcement parts
	var pb_parts: Array[String] = []
	if p1_pb.get("new_best_lap", false):
		pb_parts.append("P1 NEW BEST LAP!")
	if p1_pb.get("new_best_total", false):
		pb_parts.append("P1 NEW BEST TOTAL!")
	if p2_pb.get("new_best_lap", false):
		pb_parts.append("P2 NEW BEST LAP!")
	if p2_pb.get("new_best_total", false):
		pb_parts.append("P2 NEW BEST TOTAL!")

	if pb_parts.size() > 0:
		var pb_label := Label.new()
		pb_label.text = " | ".join(pb_parts)
		pb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pb_label.add_theme_color_override("font_color", Color(0.941, 0.784, 0.314, 1))
		pb_label.add_theme_font_size_override("font_size", 18)
		pb_label.set_meta("pb_label", true)
		# Insert after RaceBestLap label
		var insert_idx := race_best_lap.get_index() + 1
		vbox.add_child(pb_label)
		vbox.move_child(pb_label, insert_idx)
		# Gold pulse animation
		var tw := create_tween().set_loops()
		tw.tween_property(pb_label, "theme_override_colors/font_color",
			Color(1, 1, 0.6, 1), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(pb_label, "theme_override_colors/font_color",
			Color(0.941, 0.784, 0.314, 1), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Build previous best comparison lines
	var prev_parts: Array[String] = []
	if p1_pb.get("new_best_lap", false) and p1_pb.get("prev_best_lap", INF) != INF:
		prev_parts.append("P1 prev best lap: %s" % lm.format_time(p1_pb["prev_best_lap"]))
	if p1_pb.get("new_best_total", false) and p1_pb.get("prev_best_total", INF) != INF:
		prev_parts.append("P1 prev best total: %s" % lm.format_time(p1_pb["prev_best_total"]))
	if p2_pb.get("new_best_lap", false) and p2_pb.get("prev_best_lap", INF) != INF:
		prev_parts.append("P2 prev best lap: %s" % lm.format_time(p2_pb["prev_best_lap"]))
	if p2_pb.get("new_best_total", false) and p2_pb.get("prev_best_total", INF) != INF:
		prev_parts.append("P2 prev best total: %s" % lm.format_time(p2_pb["prev_best_total"]))

	if prev_parts.size() > 0:
		var prev_label := Label.new()
		prev_label.text = " | ".join(prev_parts)
		prev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prev_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.6))
		prev_label.add_theme_font_size_override("font_size", 13)
		prev_label.set_meta("pb_label", true)
		var insert_idx := race_best_lap.get_index() + 1
		# If PB label was already inserted, put this after it
		if pb_parts.size() > 0:
			insert_idx += 1
		vbox.add_child(prev_label)
		vbox.move_child(prev_label, insert_idx)

func _add_hud_backgrounds() -> void:
	# Semi-transparent dark background behind P1 HUD bar
	var p1_hud := find_child("P1HUD")
	if p1_hud:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.4)
		bg.anchors_preset = Control.PRESET_FULL_RECT
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p1_hud.add_child(bg)
		p1_hud.move_child(bg, 0)

	# Semi-transparent dark background behind P2 HUD bar
	var p2_hud := find_child("P2HUD")
	if p2_hud:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.4)
		bg.anchors_preset = Control.PRESET_FULL_RECT
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p2_hud.add_child(bg)
		p2_hud.move_child(bg, 0)

func _apply_gold_focus_to_buttons() -> void:
	# Apply gold focus border to all buttons in pause and race complete panels
	for panel in [pause_menu, race_complete_panel]:
		for child in _find_all_buttons(panel):
			_apply_gold_focus(child)

func _find_all_buttons(node: Node) -> Array:
	var buttons := []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_find_all_buttons(child))
	return buttons

func _apply_gold_focus(ctrl: Control) -> void:
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = Color(0.941, 0.784, 0.314, 1)
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(3)
	focus_style.content_margin_left = 4
	focus_style.content_margin_right = 4
	focus_style.content_margin_top = 2
	focus_style.content_margin_bottom = 2
	ctrl.add_theme_stylebox_override("focus", focus_style)

# -- Controller disconnect overlay --
var _disconnect_overlay: CenterContainer = null

func show_controller_disconnect() -> void:
	if _disconnect_overlay:
		_disconnect_overlay.visible = true
		return
	_disconnect_overlay = CenterContainer.new()
	_disconnect_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_disconnect_overlay.anchor_right = 1.0
	_disconnect_overlay.anchor_bottom = 1.0

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.custom_minimum_size = Vector2(1280, 720)
	_disconnect_overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 150)
	_disconnect_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "CONTROLLER DISCONNECTED"
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.1, 1))
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Please reconnect your controller to continue"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	add_child(_disconnect_overlay)

func hide_p2_hud() -> void:
	var p2_hud := find_child("P2HUD")
	if p2_hud:
		p2_hud.visible = false
	if _p2_drift_bar_bg:
		_p2_drift_bar_bg.visible = false

func hide_controller_disconnect() -> void:
	if _disconnect_overlay:
		_disconnect_overlay.visible = false

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

# -- Achievement toast system --

func show_achievement_toast(achievement: Dictionary) -> void:
	_achievement_toast_queue.append(achievement)
	if not _achievement_toast_active:
		_show_next_toast()

func _show_next_toast() -> void:
	if _achievement_toast_queue.is_empty():
		_achievement_toast_active = false
		return
	_achievement_toast_active = true
	var ach: Dictionary = _achievement_toast_queue.pop_front()

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.border_color = Color(0.941, 0.784, 0.314, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.anchors_preset = Control.PRESET_CENTER_TOP
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_top = 60.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.modulate.a = 0.0

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var header := Label.new()
	header.text = "ACHIEVEMENT UNLOCKED"
	header.add_theme_color_override("font_color", Color(0.941, 0.784, 0.314, 1))
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var title := Label.new()
	title.text = "%s (+%dpts)" % [ach.get("name", "???"), ach.get("points", 0)]
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = ach.get("description", "")
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	desc.add_theme_font_size_override("font_size", 13)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	panel.add_child(vbox)
	add_child(panel)

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_show_next_toast)
