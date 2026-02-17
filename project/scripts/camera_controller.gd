extends Camera2D

## Static camera that shows the full track.
## Set zoom in the inspector or via _ready to fit the track.

@export var track_center: Vector2 = Vector2(1950, 1400)
@export var camera_zoom: float = 0.28

func _ready() -> void:
	global_position = track_center
	zoom = Vector2(camera_zoom, camera_zoom)
	enabled = true
