extends Node

## AI path-following controller — attach as child of a CarPlayer node.
## Reads track centerline and steers toward a lookahead point.
## Drifts on sharp turns for speed advantage.

var _car: CharacterBody2D = null
var _centerline: Array[Vector2] = []
var _closest_idx: int = 0
var _other_car: CharacterBody2D = null
var _stuck_timer: float = 0.0

const LOOKAHEAD: int = GameConstants.AI_LOOKAHEAD_POINTS
const SHARP_TURN: float = GameConstants.AI_SHARP_TURN_ANGLE
const MISSILE_RANGE: float = GameConstants.AI_MISSILE_FIRE_DISTANCE
const ITEM_USE_SPEED: float = GameConstants.AI_ITEM_USE_SPEED

func _ready() -> void:
	_car = get_parent() as CharacterBody2D
	# Find track node (sibling of car in scene tree)
	var race_root: Node = _car.get_parent()
	var track_node: Node = race_root.get_node_or_null("Track")
	if track_node and "centerline" in track_node:
		_centerline = track_node.centerline
	# Find the other car for combat targeting
	for child: Node in race_root.get_children():
		if child is CharacterBody2D and child != _car:
			_other_car = child as CharacterBody2D
			break

func _physics_process(delta: float) -> void:
	if not _car or _centerline.is_empty() or not _car.race_started:
		return

	var n: int = _centerline.size()
	var car_pos: Vector2 = _car.global_position

	# Find closest centerline point
	var best_dist: float = INF
	for i: int in n:
		var d: float = car_pos.distance_squared_to(_centerline[i])
		if d < best_dist:
			best_dist = d
			_closest_idx = i

	# Look ahead along the centerline
	var target_idx: int = (_closest_idx + LOOKAHEAD) % n
	var target_pos: Vector2 = _centerline[target_idx]

	# Steer toward target
	var to_target: Vector2 = target_pos - car_pos
	var target_angle: float = to_target.angle() + PI / 2.0
	var angle_diff: float = wrapf(target_angle - _car.rotation, -PI, PI)
	_car.ai_steer = clampf(angle_diff / (PI * 0.25), -1.0, 1.0)

	# Throttle — always on; brake on sharp turns
	var next_idx: int = (_closest_idx + 1) % n
	var ahead_idx: int = (_closest_idx + LOOKAHEAD) % n
	var dir_now: Vector2 = (_centerline[next_idx] - _centerline[_closest_idx]).normalized()
	var dir_ahead: Vector2 = (_centerline[(ahead_idx + 1) % n] - _centerline[ahead_idx]).normalized()
	var turn_angle: float = absf(dir_now.angle_to(dir_ahead))

	if turn_angle > SHARP_TURN:
		_car.ai_throttle = 0.4
		_car.ai_brake = 0.3
		# Drift on sharp turns for speed advantage
		if _car.current_speed > _car.drift_min_speed:
			_car.ai_drift_strength = 1.0
		else:
			_car.ai_drift_strength = 0.0
	else:
		_car.ai_throttle = 1.0
		_car.ai_brake = 0.0
		# Release drift after passing turn apex
		_car.ai_drift_strength = 0.0

	# Combat — fire missiles when opponent is ahead and close
	if _other_car and _car.missile_count > 0:
		var dist_to_opponent: float = car_pos.distance_to(_other_car.global_position)
		if dist_to_opponent < MISSILE_RANGE:
			# Only fire if opponent is roughly ahead
			var to_opp: Vector2 = (_other_car.global_position - car_pos).normalized()
			var forward: Vector2 = Vector2.from_angle(_car.rotation - PI / 2.0)
			if forward.dot(to_opp) > 0.3:
				_car.ai_fire_missile_pressed = true

	# Use boost items when at speed
	if _car.has_item and _car.current_speed > ITEM_USE_SPEED:
		_car.ai_use_item_pressed = true

	# Stuck detection — reset if near-zero speed for too long
	if _car.current_speed < 30.0 and _car.hit_stun_timer <= 0.0:
		_stuck_timer += delta
		if _stuck_timer > 2.0:
			_car.reset_to_spawn()
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0
