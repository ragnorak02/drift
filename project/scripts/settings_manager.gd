class_name SettingsManager

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

# Current values (defaults)
static var master_volume: float = 1.0
static var sfx_volume: float = 1.0
static var music_volume: float = 1.0
static var controller_deadzone: float = 0.15
static var camera_zoom_offset: float = 0.0  # -0.05 to +0.05 offset from auto-computed zoom

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = cfg.get_value(SECTION, "master_volume", 1.0)
	sfx_volume = cfg.get_value(SECTION, "sfx_volume", 1.0)
	music_volume = cfg.get_value(SECTION, "music_volume", 1.0)
	controller_deadzone = cfg.get_value(SECTION, "controller_deadzone", 0.15)
	camera_zoom_offset = cfg.get_value(SECTION, "camera_zoom_offset", 0.0)
	print("[Settings] Settings loaded")

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # Preserve other sections (input mappings)
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "controller_deadzone", controller_deadzone)
	cfg.set_value(SECTION, "camera_zoom_offset", camera_zoom_offset)
	cfg.save(SETTINGS_PATH)

static func reset_defaults() -> void:
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 1.0
	controller_deadzone = 0.15
	camera_zoom_offset = 0.0
	save_settings()
	print("[Settings] Settings reset to defaults")

static func apply_audio() -> void:
	# Placeholder — will apply to AudioServer buses when audio is implemented
	pass

static func get_deadzone() -> float:
	return controller_deadzone
