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

var _track_label: Label = null
var _mode_label: Label = null

func _ready() -> void:
	SettingsManager.load_settings()

	settings_panel.visible = false
	new_run_button.grab_focus()

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
	master_slider.value_changed.connect(func(v): SettingsManager.master_volume = v)
	sfx_slider.value_changed.connect(func(v): SettingsManager.sfx_volume = v)
	music_slider.value_changed.connect(func(v): SettingsManager.music_volume = v)
	deadzone_slider.value_changed.connect(func(v): SettingsManager.controller_deadzone = v)
	zoom_slider.value_changed.connect(func(v): SettingsManager.camera_zoom_offset = v)

	# Apply gold focus style to all buttons
	_apply_gold_focus(new_run_button)
	_apply_gold_focus(settings_button)
	_apply_gold_focus(exit_button)
	_apply_gold_focus(reset_button)
	_apply_gold_focus(close_button)

	# Set focus neighbors for proper controller navigation
	new_run_button.focus_neighbor_bottom = settings_button.get_path()
	settings_button.focus_neighbor_top = new_run_button.get_path()
	settings_button.focus_neighbor_bottom = exit_button.get_path()
	exit_button.focus_neighbor_top = settings_button.get_path()

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

	# Track selection toggle — inserted before the New Run button
	var vbox: VBoxContainer = %NewRunButton.get_parent()
	var track_hbox := HBoxContainer.new()
	track_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	track_hbox.add_theme_constant_override("separation", 10)

	var track_prev := Button.new()
	track_prev.name = "TrackPrev"
	track_prev.text = "<"
	track_prev.custom_minimum_size = Vector2(40, 35)
	track_prev.pressed.connect(_on_track_prev)
	_apply_gold_focus(track_prev)
	track_hbox.add_child(track_prev)

	_track_label = Label.new()
	_track_label.add_theme_color_override("font_color", Color(0.941, 0.784, 0.314, 1))
	_track_label.add_theme_font_size_override("font_size", 18)
	_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track_label.custom_minimum_size = Vector2(200, 0)
	track_hbox.add_child(_track_label)

	var track_next := Button.new()
	track_next.name = "TrackNext"
	track_next.text = ">"
	track_next.custom_minimum_size = Vector2(40, 35)
	track_next.pressed.connect(_on_track_next)
	_apply_gold_focus(track_next)
	track_hbox.add_child(track_next)

	# Insert before the NewRunButton (index 2 = after Title + Spacer)
	vbox.add_child(track_hbox)
	vbox.move_child(track_hbox, 2)
	_update_track_label()

	# Mode selection toggle (1 Player / 2 Player) — inserted after track selector
	var mode_hbox := HBoxContainer.new()
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_hbox.add_theme_constant_override("separation", 10)

	var mode_prev := Button.new()
	mode_prev.name = "ModePrev"
	mode_prev.text = "<"
	mode_prev.custom_minimum_size = Vector2(40, 35)
	mode_prev.pressed.connect(_on_mode_toggle)
	_apply_gold_focus(mode_prev)
	mode_hbox.add_child(mode_prev)

	_mode_label = Label.new()
	_mode_label.add_theme_color_override("font_color", Color(0.941, 0.784, 0.314, 1))
	_mode_label.add_theme_font_size_override("font_size", 18)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.custom_minimum_size = Vector2(200, 0)
	mode_hbox.add_child(_mode_label)

	var mode_next := Button.new()
	mode_next.name = "ModeNext"
	mode_next.text = ">"
	mode_next.custom_minimum_size = Vector2(40, 35)
	mode_next.pressed.connect(_on_mode_toggle)
	_apply_gold_focus(mode_next)
	mode_hbox.add_child(mode_next)

	# Insert after track selector (index 3)
	vbox.add_child(mode_hbox)
	vbox.move_child(mode_hbox, 3)
	_update_mode_label()

	# Wire focus neighbors for full menu:
	# TrackSelector <-> ModeSelector <-> NewRun <-> Settings <-> Exit (wraps)
	track_prev.focus_neighbor_top = exit_button.get_path()
	track_prev.focus_neighbor_bottom = mode_prev.get_path()
	track_prev.focus_neighbor_right = track_next.get_path()
	track_next.focus_neighbor_top = exit_button.get_path()
	track_next.focus_neighbor_bottom = mode_next.get_path()
	track_next.focus_neighbor_left = track_prev.get_path()

	mode_prev.focus_neighbor_top = track_prev.get_path()
	mode_prev.focus_neighbor_bottom = new_run_button.get_path()
	mode_prev.focus_neighbor_right = mode_next.get_path()
	mode_next.focus_neighbor_top = track_next.get_path()
	mode_next.focus_neighbor_bottom = new_run_button.get_path()
	mode_next.focus_neighbor_left = mode_prev.get_path()

	new_run_button.focus_neighbor_top = mode_prev.get_path()
	exit_button.focus_neighbor_bottom = track_prev.get_path()

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
	SettingsManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings() -> void:
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
	SettingsManager.save_settings()
	get_tree().quit()

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
	_track_label.text = names[selected_track]

func _on_mode_toggle() -> void:
	player_count = 1 if player_count == 2 else 2
	_update_mode_label()

func _update_mode_label() -> void:
	_mode_label.text = "1 Player" if player_count == 1 else "2 Player"
