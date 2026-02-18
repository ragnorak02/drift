extends Node

signal lap_completed(lap_number: int, lap_time: float)
signal race_finished(total_time: float, best_lap: float)
signal lap_count_updated(current_lap: int, total_laps: int)
signal checkpoint_registered(index: int)

@export var total_laps: int = 3
@export var total_checkpoints: int = 4

var current_lap: int = 0
var checkpoints_hit: Array[int] = []
var lap_start_time: float = 0.0
var race_start_time: float = 0.0
var current_lap_time: float = 0.0
var best_lap_time: float = INF
var total_race_time: float = 0.0
var race_active: bool = false
var race_complete: bool = false
var lap_times: Array[float] = []

func start_race() -> void:
	current_lap = 1
	checkpoints_hit.clear()
	lap_times.clear()
	race_start_time = Time.get_ticks_msec() / 1000.0
	lap_start_time = race_start_time
	race_active = true
	race_complete = false
	best_lap_time = INF
	lap_count_updated.emit(current_lap, total_laps)

func _process(_delta: float) -> void:
	if race_active and not race_complete:
		var now := Time.get_ticks_msec() / 1000.0
		current_lap_time = now - lap_start_time
		total_race_time = now - race_start_time

func register_checkpoint(index: int) -> void:
	if not race_active or race_complete:
		return
	if index not in checkpoints_hit:
		checkpoints_hit.append(index)
		checkpoint_registered.emit(index)

func cross_finish_line() -> void:
	if not race_active or race_complete:
		return

	if checkpoints_hit.size() < total_checkpoints:
		return

	var lap_time := current_lap_time
	lap_times.append(lap_time)

	if lap_time < best_lap_time:
		best_lap_time = lap_time

	lap_completed.emit(current_lap, lap_time)

	if current_lap >= total_laps:
		race_complete = true
		race_active = false
		race_finished.emit(total_race_time, best_lap_time)
	else:
		current_lap += 1
		checkpoints_hit.clear()
		lap_start_time = Time.get_ticks_msec() / 1000.0
		lap_count_updated.emit(current_lap, total_laps)

func format_time(t: float) -> String:
	if t == INF or t < 0.0:
		return "--:--.---"
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	return "%d:%05.2f" % [minutes, seconds]
