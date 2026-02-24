extends RefCounted
class_name Logger

enum Level { INFO, WARN, ERROR }

static var _level_names: Array[String] = ["INFO", "WARN", "ERROR"]

static func info(category: String, message: String) -> void:
	_log(Level.INFO, category, message)

static func warn(category: String, message: String) -> void:
	_log(Level.WARN, category, message)
	push_warning("[%s] %s" % [category, message])

static func error(category: String, message: String) -> void:
	_log(Level.ERROR, category, message)
	push_error("[%s] %s" % [category, message])

static func _log(level: int, category: String, message: String) -> void:
	var time_str: String = Time.get_datetime_string_from_system(false, true)
	var level_str: String = _level_names[level]
	print("[%s] [%s] [%s] %s" % [time_str, level_str, category, message])
