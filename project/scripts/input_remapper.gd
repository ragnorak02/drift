extends RefCounted
class_name InputRemapper

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "input_mappings"

# Remappable actions (excludes UI-only actions)
static var remappable_actions: Array[String] = [
	"accelerate", "brake", "steer_left", "steer_right",
	"drift", "use_item", "fire_missile", "reset",
	"p2_accelerate", "p2_brake", "p2_steer_left", "p2_steer_right",
	"p2_drift", "p2_use_item", "p2_fire_missile", "p2_reset",
]

# Store default mappings on first load so we can reset
static var _defaults_stored: bool = false
static var _default_mappings: Dictionary = {}

static func store_defaults() -> void:
	if _defaults_stored:
		return
	for action in remappable_actions:
		if InputMap.has_action(action):
			_default_mappings[action] = InputMap.action_get_events(action).duplicate()
	_defaults_stored = true

static func remap_action(action: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		push_warning("[Input] Cannot remap unknown action: %s" % action)
		return
	store_defaults()
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_event)
	print("[Input] Remapped action: %s" % action)

static func reset_defaults() -> void:
	for action in _default_mappings:
		InputMap.action_erase_events(action)
		for event in _default_mappings[action]:
			InputMap.action_add_event(action, event)
	print("[Input] All input mappings reset to defaults")

static func save_mappings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for action in remappable_actions:
		if InputMap.has_action(action):
			var events := InputMap.action_get_events(action)
			var serialized := []
			for event in events:
				serialized.append(var_to_str(event))
			cfg.set_value(SECTION, action, serialized)
	cfg.save(SETTINGS_PATH)

static func load_mappings() -> void:
	store_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	if not cfg.has_section(SECTION):
		return
	for action in cfg.get_section_keys(SECTION):
		if not InputMap.has_action(action):
			continue
		var serialized: Array = cfg.get_value(SECTION, action, [])
		InputMap.action_erase_events(action)
		for event_str in serialized:
			var event = str_to_var(event_str)
			if event is InputEvent:
				InputMap.action_add_event(action, event)
	print("[Input] Input mappings loaded from settings")
