extends PanelContainer

## Monitors a specific input action and highlights on press.
## Attach to each hint node in the control letterbox.

@export var action_name: String = ""
@export var label_text: String = ""
@export var highlight_color: Color = Color("#f0c850")
@export var normal_color: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var fade_duration: float = 0.3

@onready var label: Label = $Label

var _tween: Tween = null
var _style: StyleBoxFlat

func _ready() -> void:
	# Create a unique style so highlights don't share state
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	_style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(4)
	_style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", _style)

	if label:
		label.text = label_text
		label.add_theme_color_override("font_color", normal_color)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	custom_minimum_size = Vector2(52, 32)

func _process(_delta: float) -> void:
	if action_name.is_empty():
		return

	if Input.is_action_pressed(action_name):
		_highlight()
	# Note: fade happens via tween on release, handled in _input

func _input(event: InputEvent) -> void:
	if action_name.is_empty():
		return
	if event.is_action_released(action_name):
		_fade_out()

func _highlight() -> void:
	if _tween:
		_tween.kill()
	_style.border_color = highlight_color
	_style.bg_color = Color(highlight_color, 0.3)
	if label:
		label.add_theme_color_override("font_color", highlight_color)

func _fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_style, "border_color", Color(0.3, 0.3, 0.4, 1.0), fade_duration)
	_tween.tween_property(_style, "bg_color", Color(0.15, 0.15, 0.2, 0.8), fade_duration)
	if label:
		_tween.tween_property(label, "theme_override_colors/font_color", normal_color, fade_duration)
