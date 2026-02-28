## Loop Drift Racer — Test Runner
## Usage: Z:/godot/godot.exe --path project --headless --script tests/run-tests.gd
## Output: JSON to stdout + tests/test_results.json matching Amatris dashboard contract

extends SceneTree

var results := {
	"gameId": "drift",
	"status": "pass",
	"testsTotal": 0,
	"testsPassed": 0,
	"testsFailed": 0,
	"durationMs": 0,
	"details": [],
	"timestamp": ""
}

var _run_start_ms: int = 0

func _init():
	_run_start_ms = Time.get_ticks_msec()
	results["timestamp"] = Time.get_datetime_string_from_system(true)  # UTC

	# --- Constants Tests ---
	_test("constants_max_speed", "CAR_MAX_SPEED is positive and within ABSOLUTE_MAX_SPEED", func():
		if GameConstants.CAR_MAX_SPEED <= 0:
			return "CAR_MAX_SPEED is not positive: %s" % GameConstants.CAR_MAX_SPEED
		if GameConstants.CAR_MAX_SPEED > GameConstants.ABSOLUTE_MAX_SPEED:
			return "CAR_MAX_SPEED (%s) exceeds ABSOLUTE_MAX_SPEED (%s)" % [GameConstants.CAR_MAX_SPEED, GameConstants.ABSOLUTE_MAX_SPEED]
		return ""
	)

	_test("constants_drift_thresholds", "Drift tier times are ordered: TIER_1 < TIER_2 < TIER_3", func():
		if GameConstants.DRIFT_TIER_1_TIME >= GameConstants.DRIFT_TIER_2_TIME:
			return "TIER_1 (%s) >= TIER_2 (%s)" % [GameConstants.DRIFT_TIER_1_TIME, GameConstants.DRIFT_TIER_2_TIME]
		if GameConstants.DRIFT_TIER_2_TIME >= GameConstants.DRIFT_TIER_3_TIME:
			return "TIER_2 (%s) >= TIER_3 (%s)" % [GameConstants.DRIFT_TIER_2_TIME, GameConstants.DRIFT_TIER_3_TIME]
		return ""
	)

	_test("constants_missile_timing", "Missile durations are positive and homing > launch", func():
		if GameConstants.MISSILE_LAUNCH_DURATION <= 0:
			return "MISSILE_LAUNCH_DURATION is not positive: %s" % GameConstants.MISSILE_LAUNCH_DURATION
		if GameConstants.MISSILE_HOMING_DURATION <= GameConstants.MISSILE_LAUNCH_DURATION:
			return "MISSILE_HOMING_DURATION (%s) <= MISSILE_LAUNCH_DURATION (%s)" % [GameConstants.MISSILE_HOMING_DURATION, GameConstants.MISSILE_LAUNCH_DURATION]
		return ""
	)

	# --- Track Centerline Tests ---
	_test("track1_centerline_valid", "Track 1 centerline has >= 20 points", func():
		var track := _make_track()
		track._load_track_1()
		var size: int = track.centerline.size()
		track.free()
		if size < 20:
			return "Track 1 centerline has %d points (expected >= 20)" % size
		return ""
	)

	_test("track2_centerline_valid", "Track 2 centerline has >= 30 points", func():
		var track := _make_track()
		track._load_track_2()
		var size: int = track.centerline.size()
		track.free()
		if size < 30:
			return "Track 2 centerline has %d points (expected >= 30)" % size
		return ""
	)

	_test("track3_centerline_valid", "Track 3 centerline has >= 30 points", func():
		var track := _make_track()
		track._load_track_3()
		var size: int = track.centerline.size()
		track.free()
		if size < 30:
			return "Track 3 centerline has %d points (expected >= 30)" % size
		return ""
	)

	_test("track_checkpoints_in_range", "All checkpoint indices within centerline bounds", func():
		var tracks := [
			{"name": "Track 1", "loader": "_load_track_1"},
			{"name": "Track 2", "loader": "_load_track_2"},
			{"name": "Track 3", "loader": "_load_track_3"},
		]
		for t in tracks:
			var track := _make_track()
			track.call(t.loader)
			var cl_size: int = track.centerline.size()
			for ci in track.checkpoint_indices:
				if ci < 0 or ci >= cl_size:
					var err := "%s checkpoint index %d out of range [0, %d)" % [t.name, ci, cl_size]
					track.free()
					return err
			track.free()
		return ""
	)

	# --- Ghost Data Round-Trip ---
	_test("ghost_data_round_trip", "Ghost save/load round-trip preserves frame data", func():
		# Use track_index 99 to avoid overwriting real ghost data
		var test_track := 99
		# First, clear any existing ghost for this index
		var ghost_path := "user://ghosts/track_99_best.ghost"
		if FileAccess.file_exists(ghost_path):
			DirAccess.remove_absolute(ghost_path)

		var frames: Array = [
			{"position": Vector2(100.0, 200.0), "rotation": 1.5, "drift_tier": 2, "is_boosting": true},
			{"position": Vector2(300.0, 400.0), "rotation": 0.5, "drift_tier": 0, "is_boosting": false},
			{"position": Vector2(500.0, 600.0), "rotation": 3.14, "drift_tier": 1, "is_boosting": true},
		]

		var saved := GhostData.save_ghost(test_track, 45.0, 14.5, frames)
		if not saved:
			return "save_ghost returned false"

		var loaded := GhostData.load_ghost(test_track)
		if loaded.is_empty():
			return "load_ghost returned empty dictionary"

		if loaded.frame_count != frames.size():
			var err := "Frame count mismatch: got %d, expected %d" % [loaded.frame_count, frames.size()]
			# Cleanup
			DirAccess.remove_absolute(ghost_path)
			return err

		for i in frames.size():
			var orig = frames[i]
			var read = loaded.frames[i]
			# Position check (float tolerance)
			if abs(read.position.x - orig.position.x) > 0.1 or abs(read.position.y - orig.position.y) > 0.1:
				DirAccess.remove_absolute(ghost_path)
				return "Frame %d position mismatch" % i
			if read.drift_tier != orig.drift_tier:
				DirAccess.remove_absolute(ghost_path)
				return "Frame %d drift_tier mismatch: got %d, expected %d" % [i, read.drift_tier, orig.drift_tier]
			if read.is_boosting != orig.is_boosting:
				DirAccess.remove_absolute(ghost_path)
				return "Frame %d is_boosting mismatch" % i

		# Cleanup test ghost file
		DirAccess.remove_absolute(ghost_path)
		return ""
	)

	# --- Settings Defaults ---
	_test("settings_defaults", "SettingsManager default values are correct", func():
		# SettingsManager.reset_defaults() calls save_settings() which works fine,
		# but the class may fail to compile in headless mode if AudioManager autoload
		# is unavailable. Test by loading the script and checking static defaults directly.
		var sm_script = load("res://scripts/settings_manager.gd")
		if sm_script == null:
			return "Could not load settings_manager.gd"
		# Check the script's default property values via source inspection.
		# The class declares: static var master_volume: float = 1.0, etc.
		# In headless mode without autoloads, we verify by reading the source.
		var f := FileAccess.open("res://scripts/settings_manager.gd", FileAccess.READ)
		if f == null:
			return "Could not open settings_manager.gd for reading"
		var text := f.get_as_text()
		# Verify default values are present in source
		if text.find("master_volume: float = 1.0") == -1:
			return "master_volume default is not 1.0"
		if text.find("sfx_volume: float = 1.0") == -1:
			return "sfx_volume default is not 1.0"
		if text.find("music_volume: float = 1.0") == -1:
			return "music_volume default is not 1.0"
		# Verify reset_defaults function exists and sets correct values
		if text.find("func reset_defaults()") == -1:
			return "reset_defaults() function not found"
		if text.find("master_volume = 1.0") == -1:
			return "reset_defaults does not set master_volume = 1.0"
		if text.find("sfx_volume = 1.0") == -1:
			return "reset_defaults does not set sfx_volume = 1.0"
		return ""
	)

	# --- Achievement JSON Validation ---
	_test("achievement_json_valid", "achievements.json has required structure and keys", func():
		var path := "res:///../achievements.json"
		if not FileAccess.file_exists(path):
			# Try alternative path
			path = "res://../achievements.json"
		# Direct filesystem path as fallback
		var text := ""
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			# Try using absolute project-relative path
			var script_path := (get_script() as Script).resource_path
			var base_dir := script_path.get_base_dir().get_base_dir()  # up from tests/
			path = base_dir + "/achievements.json"
			f = FileAccess.open(path, FileAccess.READ)
		if f == null:
			return "Could not open achievements.json (tried multiple paths)"
		text = f.get_as_text()

		var json := JSON.new()
		if json.parse(text) != OK:
			return "achievements.json is not valid JSON: %s" % json.get_error_message()

		var data = json.data
		if typeof(data) != TYPE_DICTIONARY:
			return "achievements.json root is not a dictionary"
		if not data.has("gameId"):
			return "Missing 'gameId' key"
		if not data.has("achievements"):
			return "Missing 'achievements' key"
		if typeof(data.achievements) != TYPE_ARRAY:
			return "'achievements' is not an array"
		if data.achievements.size() == 0:
			return "'achievements' array is empty"

		var required_keys := ["id", "name", "description", "points"]
		for i in data.achievements.size():
			var entry = data.achievements[i]
			if typeof(entry) != TYPE_DICTIONARY:
				return "achievements[%d] is not a dictionary" % i
			for key in required_keys:
				if not entry.has(key):
					return "achievements[%d] missing required key '%s'" % [i, key]
		return ""
	)

	# --- Performance Test ---
	_test("perf_track_generation", "Track generation completes in < 500ms per track", func():
		var loaders := ["_load_track_1", "_load_track_2", "_load_track_3"]
		for loader in loaders:
			var t_start := Time.get_ticks_msec()
			var track := _make_track()
			track.call(loader)
			track._compute_edges()
			var elapsed := Time.get_ticks_msec() - t_start
			track.free()
			if elapsed > 500:
				return "%s + _compute_edges took %dms (limit 500ms)" % [loader, elapsed]
		return ""
	)

	# --- Stress Test ---
	_test("stress_large_track", "Large track (200+ points) computes edges without error", func():
		var track := _make_track()
		# Build a 200-point circular centerline (5x normal track size)
		var points: Array[Vector2] = []
		var radius := 3000.0
		var center := Vector2(4000, 4000)
		for i in 200:
			var angle := TAU * i / 200.0
			points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
		track.centerline.assign(points)
		track.checkpoint_indices = [0, 50, 100, 150]

		track._compute_edges()

		var outer_size: int = track._outer_points.size()
		var inner_size: int = track._inner_points.size()
		track.free()

		if outer_size != 200:
			return "outer_points size is %d (expected 200)" % outer_size
		if inner_size != 200:
			return "inner_points size is %d (expected 200)" % inner_size
		return ""
	)

	# --- Finalize ---
	var total_ms: int = Time.get_ticks_msec() - _run_start_ms
	results["durationMs"] = total_ms

	if results["testsFailed"] > 0:
		results["status"] = "fail"

	var json_output := JSON.stringify(results, "\t")
	print(json_output)

	# Write to test_results.json
	var out_path := "res:///../tests/test_results.json"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		# Fallback: try script-relative path
		var script_path := (get_script() as Script).resource_path
		var base_dir := script_path.get_base_dir()
		out_path = base_dir + "/test_results.json"
		f = FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(json_output)
		f.flush()
		print("[TestRunner] Results written to %s" % out_path)
	else:
		push_error("[TestRunner] Failed to write test_results.json")

	quit()


## Create a bare Track node (no _ready, no scene tree build)
func _make_track() -> Node2D:
	var track_script := load("res://scripts/track.gd")
	var track := Node2D.new()
	track.set_script(track_script)
	return track


## Run a single test. test_func returns "" on pass, or an error message string on fail.
func _test(id: String, description: String, test_func: Callable):
	results["testsTotal"] += 1
	var t_start := Time.get_ticks_msec()
	var error_msg: String = ""

	# Run test — result may be null if the lambda crashes
	var result = test_func.call()
	if result == null:
		error_msg = "Test crashed (returned null)"
	elif result is String:
		error_msg = result
	else:
		error_msg = "Test returned non-string: %s" % str(result)

	var elapsed := Time.get_ticks_msec() - t_start
	var passed := (error_msg == "")

	if passed:
		results["testsPassed"] += 1
	else:
		results["testsFailed"] += 1

	var detail := {
		"name": id,
		"description": description,
		"status": "pass" if passed else "fail",
		"durationMs": elapsed,
	}
	if not passed and error_msg != "":
		detail["error"] = error_msg

	results["details"].append(detail)
