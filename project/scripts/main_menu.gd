extends Control

@onready var new_run_button: Button = %NewRunButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var settings_panel: PanelContainer = %SettingsPanel

# Settings sliders
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var deadzone_slider: HSlider = %DeadzoneSlider
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var reset_button: Button = %ResetButton
@onready var close_button: Button = %CloseButton

# Track selection — shared via static var so track.gd can read it
static var selected_track: int = 0

# Player count — shared via static var so race_manager can read it
static var player_count: int = 2

var _track_button: Button = null
var _mode_button: Button = null

func _ready() -> void:
	SettingsManager.load_settings()

	settings_panel.visible = false

	new_run_button.pressed.connect(_on_new_run)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(_on_exit)
	reset_button.pressed.connect(_on_reset_defaults)
	close_button.pressed.connect(_on_close_settings)

	# Load slider values from settings
	master_slider.value = SettingsManager.master_volume
	sfx_slider.value = SettingsManager.sfx_volume
	music_slider.value = SettingsManager.music_volume
	deadzone_slider.value = SettingsManager.controller_deadzone
	zoom_slider.value = SettingsManager.camera_zoom_offset

	# Connect slider changes
	master_slider.value_changed.connect(func(v): SettingsManager.master_volume = v; SettingsManager.apply_audio())
	sfx_slider.value_changed.connect(func(v): SettingsManager.sfx_volume = v; SettingsManager.apply_audio())
	music_slider.value_changed.connect(func(v): SettingsManager.music_volume = v; SettingsManager.apply_audio())
	deadzone_slider.value_changed.connect(func(v): SettingsManager.controller_deadzone = v)
	zoom_slider.value_changed.connect(func(v): SettingsManager.camera_zoom_offset = v)

	# Apply gold focus style to all buttons
	_apply_gold_focus(new_run_button)
	_apply_gold_focus(settings_button)
	_apply_gold_focus(exit_button)
	_apply_gold_focus(reset_button)
	_apply_gold_focus(close_button)

	# Version label (bottom-right)
	var ver := Label.new()
	ver.text = "v%s" % GameConstants.VERSION
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	ver.add_theme_font_size_override("font_size", 12)
	ver.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	ver.anchor_left = 1.0
	ver.anchor_top = 1.0
	ver.anchor_right = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -80.0
	ver.offset_top = -25.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)

	# Track selection — single button showing "< Track Name >"
	var vbox: VBoxContainer = %NewRunButton.get_parent()

	_track_button = Button.new()
	_track_button.name = "TrackSelector"
	_track_button.custom_minimum_size = Vector2(300, 40)
	_track_button.pressed.connect(_on_track_next)
	_apply_gold_focus(_track_button)
	vbox.add_child(_track_button)
	vbox.move_child(_track_button, 2)  # After Title + Spacer
	_update_track_label()

	# Mode selection — single button showing "< 1 Player >" / "< 2 Player >"
	_mode_button = Button.new()
	_mode_button.name = "ModeSelector"
	_mode_button.custom_minimum_size = Vector2(300, 40)
	_mode_button.pressed.connect(_on_mode_toggle)
	_apply_gold_focus(_mode_button)
	vbox.add_child(_mode_button)
	vbox.move_child(_mode_button, 3)  # After track selector
	_update_mode_label()

	# --- Vertical focus chain: Track → Mode → NewRun → Settings → Exit (wraps) ---
	var menu_buttons: Array[Control] = [_track_button, _mode_button, new_run_button, settings_button, exit_button]
	for i in menu_buttons.size():
		var btn := menu_buttons[i]
		var prev := menu_buttons[(i - 1 + menu_buttons.size()) % menu_buttons.size()]
		var next := menu_buttons[(i + 1) % menu_buttons.size()]
		btn.focus_neighbor_top = prev.get_path()
		btn.focus_neighbor_bottom = next.get_path()
		# Lock left/right to self — prevents horizontal stick from escaping
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()

	# Give initial focus to track selector (top of chain)
	_track_button.grab_focus()

	# Start menu music
	AudioManager.start_menu_music()

	# Navigate sounds on focus changes
	for btn: Control in [_track_button, _mode_button, new_run_button, settings_button, exit_button, reset_button, close_button]:
		btn.focus_entered.connect(AudioManager.play_menu_navigate)

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

func _on_new_run() -> void:
	AudioManager.play_menu_select()
	AudioManager.stop_menu_music()
	SettingsManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings() -> void:
	AudioManager.play_menu_select()
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible:
		master_slider.grab_focus()
	else:
		settings_button.grab_focus()

func _on_close_settings() -> void:
	SettingsManager.save_settings()
	settings_panel.visible = false
	settings_button.grab_focus()

func _on_reset_defaults() -> void:
	SettingsManager.reset_defaults()
	master_slider.value = SettingsManager.master_volume
	sfx_slider.value = SettingsManager.sfx_volume
	music_slider.value = SettingsManager.music_volume
	deadzone_slider.value = SettingsManager.controller_deadzone
	zoom_slider.value = SettingsManager.camera_zoom_offset

func _on_exit() -> void:
	AudioManager.play_menu_select()
	SettingsManager.save_settings()
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if settings_panel.visible:
		return
	# Left/right on track or mode selector cycles the value
	if _track_button != null and _track_button.has_focus():
		if event.is_action_pressed("ui_left"):
			_on_track_prev()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_on_track_next()
			get_viewport().set_input_as_handled()
	elif _mode_button != null and _mode_button.has_focus():
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_on_mode_toggle()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Allow LB/RB (shoulder buttons) to cycle tracks from anywhere in menu
	if settings_panel.visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_on_track_prev()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_on_track_next()
			get_viewport().set_input_as_handled()

func _on_track_prev() -> void:
	selected_track = (selected_track - 1 + 2) % 2
	_update_track_label()

func _on_track_next() -> void:
	selected_track = (selected_track + 1) % 2
	_update_track_label()

func _update_track_label() -> void:
	var names := ["Track 1: Grand Circuit", "Track 2: Figure Eight"]
	_track_button.text = "<  %s  >" % names[selected_track]

func _on_mode_toggle() -> void:
	player_count = 1 if player_count == 2 else 2
	_update_mode_label()

func _update_mode_label() -> void:
	var label := "1 Player" if player_count == 1 else "2 Player"
	_mode_button.text = "<  %s  >" % label
