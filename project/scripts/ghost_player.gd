extends Node2D

## Plays back a recorded ghost run as a translucent car visual.
## No physics, no collision, no input.

var _frames: Array[Dictionary] = []
var _frame_index: int = 0
var _playing := false
var _body: Polygon2D = null
var _nose: Polygon2D = null
var _label: Label = null

# Drift tier colors (same scheme as car_controller.gd, reduced opacity)
var _tier_colors := [
	GameConstants.GHOST_BASE_COLOR,               # Tier 0 — silver
	Color(1.0, 0.55, 0.0, 1.0),                   # Tier 1 — orange
	Color(1.0, 0.15, 0.0, 1.0),                   # Tier 2 — red
	Color(0.7, 0.2, 1.0, 1.0),                    # Tier 3 — purple
]

func _ready() -> void:
	z_index = -1
	modulate.a = GameConstants.GHOST_ALPHA

	# Car body — matches CarPlayer.tscn shape
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-15, -25), Vector2(15, -25),
		Vector2(15, 25), Vector2(-15, 25),
	])
	_body.color = GameConstants.GHOST_BASE_COLOR
	add_child(_body)

	# Nose indicator
	_nose = Polygon2D.new()
	_nose.polygon = PackedVector2Array([
		Vector2(-8, -25), Vector2(8, -25), Vector2(0, -35),
	])
	_nose.color = Color(1.0, 0.9, 0.7, 1.0)
	add_child(_nose)

	# "GHOST" label
	_label = Label.new()
	_label.text = "GHOST"
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.8))
	_label.position = Vector2(-18, -50)
	add_child(_label)

	visible = false

func load_frames(frames: Array) -> void:
	_frames.assign(frames)

func start_playback() -> void:
	if _frames.is_empty():
		return
	_frame_index = 0
	_playing = true
	visible = true

func stop_playback() -> void:
	_playing = false
	visible = false

func _physics_process(_delta: float) -> void:
	if not _playing or _frames.is_empty():
		return

	if _frame_index >= _frames.size():
		# Ghost finished its run — hide
		visible = false
		_playing = false
		return

	var frame: Dictionary = _frames[_frame_index]
	global_position = frame.position
	rotation = frame.rotation

	# Update color by drift tier
	var tier: int = clampi(frame.drift_tier, 0, 3)
	_body.color = _tier_colors[tier]

	# Boost glow
	if frame.is_boosting:
		_body.color = Color(1.0, 0.3, 0.1, 1.0)

	_frame_index += 1
