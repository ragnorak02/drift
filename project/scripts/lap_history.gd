class_name LapHistory
extends RefCounted

const HISTORY_PATH := "user://lap_history.cfg"
const MAX_RACES := 20

# Cached PB values
static var _best_lap_p1: float = INF
static var _best_lap_p2: float = INF
static var _best_total_p1: float = INF
static var _best_total_p2: float = INF
static var _loaded: bool = false

static func load_history() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(HISTORY_PATH) != OK:
		_best_lap_p1 = INF
		_best_lap_p2 = INF
		_best_total_p1 = INF
		_best_total_p2 = INF
		_loaded = true
		return
	_best_lap_p1 = cfg.get_value("pb_p1", "best_lap_time", INF)
	_best_total_p1 = cfg.get_value("pb_p1", "best_total_time", INF)
	_best_lap_p2 = cfg.get_value("pb_p2", "best_lap_time", INF)
	_best_total_p2 = cfg.get_value("pb_p2", "best_total_time", INF)
	_loaded = true
	print("[LapHistory] History loaded — P1 best lap: %.2f, P2 best lap: %.2f" % [_best_lap_p1, _best_lap_p2])

static func _ensure_loaded() -> void:
	if not _loaded:
		load_history()

static func get_best_lap(player_id: int) -> float:
	_ensure_loaded()
	return _best_lap_p1 if player_id == 1 else _best_lap_p2

static func get_best_total(player_id: int) -> float:
	_ensure_loaded()
	return _best_total_p1 if player_id == 1 else _best_total_p2

static func save_race(player_id: int, track_index: int, total_time: float, best_lap: float, lap_times: Array, won: bool) -> Dictionary:
	_ensure_loaded()
	var pb_section := "pb_p%d" % player_id
	var hist_section := "history_p%d" % player_id

	var prev_best_lap := get_best_lap(player_id)
	var prev_best_total := get_best_total(player_id)

	var new_best_lap := best_lap < prev_best_lap
	var new_best_total := won and total_time < prev_best_total

	# Update cached PBs
	if new_best_lap:
		if player_id == 1:
			_best_lap_p1 = best_lap
		else:
			_best_lap_p2 = best_lap

	if new_best_total:
		if player_id == 1:
			_best_total_p1 = total_time
		else:
			_best_total_p2 = total_time

	# Build race record
	var now := Time.get_datetime_string_from_system()
	var date_str: String = now.left(16) if now.length() >= 16 else now
	var record := JSON.stringify({
		"track": track_index,
		"total_time": snapped(total_time, 0.01),
		"best_lap": snapped(best_lap, 0.01),
		"lap_times": lap_times,
		"date": date_str,
		"won": won,
	})

	# Save to ConfigFile
	var cfg := ConfigFile.new()
	cfg.load(HISTORY_PATH)

	# PB section
	cfg.set_value(pb_section, "best_lap_time", get_best_lap(player_id))
	cfg.set_value(pb_section, "best_total_time", get_best_total(player_id))

	# History section — FIFO ring of MAX_RACES entries
	var race_count: int = cfg.get_value(hist_section, "race_count", 0)
	# Shift old entries if at max
	if race_count >= MAX_RACES:
		for i in range(0, MAX_RACES - 1):
			var next_val: String = cfg.get_value(hist_section, "race_%d" % (i + 1), "")
			cfg.set_value(hist_section, "race_%d" % i, next_val)
		race_count = MAX_RACES - 1
	cfg.set_value(hist_section, "race_%d" % race_count, record)
	cfg.set_value(hist_section, "race_count", race_count + 1)

	cfg.save(HISTORY_PATH)
	print("[LapHistory] P%d race saved — best_lap: %.2f, total: %.2f, won: %s" % [player_id, best_lap, total_time, str(won)])

	return {
		"new_best_lap": new_best_lap,
		"new_best_total": new_best_total,
		"prev_best_lap": prev_best_lap,
		"prev_best_total": prev_best_total,
	}

static func get_total_race_count() -> int:
	_ensure_loaded()
	var cfg := ConfigFile.new()
	if cfg.load(HISTORY_PATH) != OK:
		return 0
	var p1_count: int = cfg.get_value("history_p1", "race_count", 0)
	var p2_count: int = cfg.get_value("history_p2", "race_count", 0)
	return p1_count + p2_count

static func reset_history() -> void:
	var cfg := ConfigFile.new()
	cfg.save(HISTORY_PATH)
	_best_lap_p1 = INF
	_best_lap_p2 = INF
	_best_total_p1 = INF
	_best_total_p2 = INF
	_loaded = true
	print("[LapHistory] History reset")
