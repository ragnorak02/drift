extends Node

## Records car state each physics frame for ghost replay.
## Attach as child of a CarPlayer node.

var _recording := false
var _frames: Array[Dictionary] = []

func start_recording() -> void:
	_frames.clear()
	_recording = true

func stop_recording() -> void:
	_recording = false

func get_frames() -> Array[Dictionary]:
	return _frames

func _physics_process(_delta: float) -> void:
	if not _recording:
		return
	var car := get_parent()
	_frames.append({
		"position": car.global_position,
		"rotation": car.rotation,
		"drift_tier": car.drift_tier,
		"is_boosting": car.is_boosting,
	})
