extends Control

@onready var new_run_button: Button = %NewRunButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var settings_panel: PanelContainer = %SettingsPanel

func _ready() -> void:
	settings_panel.visible = false
	new_run_button.grab_focus()

	new_run_button.pressed.connect(_on_new_run)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(_on_exit)

func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings() -> void:
	settings_panel.visible = not settings_panel.visible

func _on_exit() -> void:
	get_tree().quit()
