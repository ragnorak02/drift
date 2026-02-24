class_name AchievementManager
extends RefCounted

static var _achievements: Array = []
static var _meta: Dictionary = {}
static var _loaded: bool = false
static var _on_unlock_callbacks: Array[Callable] = []

static func _get_achievements_path() -> String:
	var project_dir := ProjectSettings.globalize_path("res://")
	return project_dir.path_join("../achievements.json").simplify_path()

static func load_achievements() -> void:
	var path := _get_achievements_path()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[Achievements] Could not open %s" % path)
		_achievements = []
		_meta = {}
		_loaded = true
		return
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		print("[Achievements] Failed to parse achievements.json")
		_achievements = []
		_meta = {}
		_loaded = true
		return
	_achievements = data.get("achievements", [])
	_meta = data.get("meta", {})
	_loaded = true
	print("[Achievements] Loaded %d achievements (%d pts earned)" % [_achievements.size(), _meta.get("totalPointsEarned", 0)])

static func _ensure_loaded() -> void:
	if not _loaded:
		load_achievements()

static func is_unlocked(id: String) -> bool:
	_ensure_loaded()
	for a in _achievements:
		if a.get("id", "") == id:
			return a.get("unlocked", false)
	return false

static func try_unlock(id: String) -> bool:
	_ensure_loaded()
	if is_unlocked(id):
		return false
	for a in _achievements:
		if a.get("id", "") == id:
			a["unlocked"] = true
			a["unlockedAt"] = _get_iso_timestamp()
			_recalculate_points()
			_save_achievements()
			print("[Achievements] Unlocked: %s — %s (+%d pts)" % [a.get("name", id), a.get("description", ""), a.get("points", 0)])
			for cb in _on_unlock_callbacks:
				if cb.is_valid():
					cb.call(a)
			return true
	print("[Achievements] Unknown achievement id: %s" % id)
	return false

static func _recalculate_points() -> void:
	var total := 0
	for a in _achievements:
		if a.get("unlocked", false):
			total += a.get("points", 0)
	_meta["totalPointsEarned"] = total
	_meta["lastUpdated"] = _get_iso_timestamp()

static func _save_achievements() -> void:
	var path := _get_achievements_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("[Achievements] Could not write to %s" % path)
		return
	var data := {
		"gameId": "drift",
		"achievements": _achievements,
		"meta": _meta,
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

static func register_unlock_callback(cb: Callable) -> void:
	_on_unlock_callbacks.append(cb)

static func clear_callbacks() -> void:
	_on_unlock_callbacks.clear()

static func _get_iso_timestamp() -> String:
	var dt := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:00.000Z" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]
