extends Area2D

enum State { LAUNCH, HOMING, EXPIRED }

@export var launch_speed: float = 1800.0
@export var homing_speed: float = 1400.0
@export var homing_turn_rate: float = 2.5
@export var launch_duration: float = 1.0
@export var homing_duration: float = 4.0

var state: int = State.LAUNCH
var direction: Vector2 = Vector2.UP
var source_car: CharacterBody2D = null
var target_car: CharacterBody2D = null
var _timer: float = 0.0
var _body: Polygon2D = null
var _glow: Polygon2D = null
var _trail: Line2D = null

func _ready() -> void:
	# Pointed missile shape (fiery red-orange)
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(6, -4),
		Vector2(5, 10), Vector2(-5, 10),
		Vector2(-6, -4)
	])
	_body.color = Color(1.0, 0.3, 0.05, 1.0)
	add_child(_body)

	# Pulsing glow
	_glow = Polygon2D.new()
	_glow.polygon = _make_circle(14, 10)
	_glow.color = Color(1.0, 0.4, 0.1, 0.3)
	_glow.z_index = -1
	add_child(_glow)

	# Gradient trail
	_trail = Line2D.new()
	_trail.width = 6.0
	_trail.top_level = true
	_trail.z_index = -1
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.3, 0, 0))
	grad.set_color(1, Color(1, 0.5, 0.1, 0.7))
	_trail.gradient = grad
	add_child(_trail)

	# Collision shape
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	add_child(col)

	# Set collision to not interact with walls (passes through)
	collision_layer = 0
	collision_mask = 1  # Only collide with cars on layer 1

	body_entered.connect(_on_body_entered)
	rotation = direction.angle() + PI / 2.0

func _process(delta: float) -> void:
	_timer += delta

	match state:
		State.LAUNCH:
			position += direction * launch_speed * delta
			if _timer >= launch_duration:
				state = State.HOMING
				_timer = 0.0

		State.HOMING:
			if target_car and is_instance_valid(target_car):
				var to_target := (target_car.global_position - global_position).normalized()
				var cross := direction.cross(to_target)
				var turn := clampf(cross, -1.0, 1.0) * homing_turn_rate * delta
				direction = direction.rotated(turn).normalized()
			position += direction * homing_speed * delta
			rotation = direction.angle() + PI / 2.0
			if _timer >= homing_duration:
				_expire()

		State.EXPIRED:
			return

	# Trail
	_trail.add_point(global_position)
	if _trail.get_point_count() > 20:
		_trail.remove_point(0)

	# Pulsing glow
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
	_glow.scale = Vector2(pulse, pulse)

func _on_body_entered(body: Node2D) -> void:
	if body == source_car:
		return
	if body is CharacterBody2D and body.has_method("hit_by_missile"):
		body.hit_by_missile(direction)
		_expire()

func _expire() -> void:
	state = State.EXPIRED
	_body.visible = false
	_glow.visible = false
	# Quick fade trail then free
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(queue_free)

func _make_circle(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points
