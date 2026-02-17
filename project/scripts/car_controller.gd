extends CharacterBody2D

signal speed_changed(speed: float)
signal drift_state_changed(is_drifting: bool)

# -- Movement (all reduced 25% from previous) --
@export var acceleration: float = 900.0
@export var max_speed: float = 1200.0
@export var brake_force: float = 600.0
@export var reverse_max_speed: float = 300.0
@export var drag: float = 0.98

# -- Steering --
@export var steering_speed: float = 3.0
@export var steering_curve: float = 0.7
@export var mouse_steer_speed: float = 4.0
@export var drift_steer_multiplier: float = 1.2

# -- Traction / Drift --
@export var base_traction: float = 0.85
@export var drift_traction: float = 0.03
@export var traction_transition_speed: float = 10.0
@export var min_jump_speed: float = 80.0
@export var drift_decel: float = 600.0

# -- Jump --
@export var hop_scale: float = 1.6
@export var hop_duration: float = 0.35
## Collision layer for jump-only walls (car ignores these while hopping)
@export var jump_wall_layer: int = 2

# -- Boost on release --
@export var boost_base: float = 225.0
@export var boost_per_second: float = 375.0
@export var boost_max: float = 1050.0
@export var charge_full_time: float = 2.0

# -- Item boost --
@export var item_boost_speed: float = 500.0
@export var item_boost_duration: float = 2.5

# -- Colors --
var color_normal := Color(0.2, 0.6, 1.0, 1.0)
var color_charge_mid := Color(1.0, 0.55, 0.0, 1.0)
var color_charge_full := Color(1.0, 0.15, 0.0, 1.0)
var color_nose_normal := Color(1.0, 0.9, 0.2, 1.0)
var color_item_boost := Color(0.0, 1.0, 0.5, 1.0)

# -- State --
var current_speed: float = 0.0
var current_traction: float = 0.85
var is_drifting: bool = false
var is_jumping: bool = false
var jump_held: bool = false
var drift_time: float = 0.0
var charge_ratio: float = 0.0
var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var is_hopping: bool = false
var is_boosting: bool = false
var boost_timer: float = 0.0
var use_mouse_steer: bool = false
var mouse_world_pos: Vector2 = Vector2.ZERO

# Item boost state
var has_item: bool = false
var item_boost_active: bool = false
var item_boost_timer: float = 0.0

var spawn_position: Vector2 = Vector2.ZERO
var spawn_rotation: float = 0.0
var race_started: bool = false
var _original_collision_mask: int = 0

var _hop_tween: Tween = null
var _car_sprite: Polygon2D = null
var _nose_sprite: Polygon2D = null
var _shadow: Polygon2D = null
var _trail: Line2D = null
var _trail_timer: float = 0.0
var _item_trail: Line2D = null
const TRAIL_DURATION := 0.6
const TRAIL_MAX_POINTS := 30

func _ready() -> void:
	spawn_position = global_position
	spawn_rotation = rotation
	_car_sprite = $CarSprite
	_nose_sprite = $NoseIndicator
	_original_collision_mask = collision_mask
	_create_shadow()
	_create_trail()
	_create_item_trail()

func _create_shadow() -> void:
	_shadow = Polygon2D.new()
	_shadow.polygon = PackedVector2Array([
		Vector2(-14, -24), Vector2(14, -24),
		Vector2(14, 24), Vector2(-14, 24)
	])
	_shadow.color = Color(0, 0, 0, 0.35)
	_shadow.z_index = -1
	_shadow.visible = false
	add_child(_shadow)

func _create_trail() -> void:
	_trail = Line2D.new()
	_trail.width = 12.0
	_trail.default_color = Color(1, 0.1, 0, 0.8)
	_trail.top_level = true
	_trail.z_index = -1
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.1, 0, 0))
	grad.set_color(1, Color(1, 0.2, 0, 0.9))
	_trail.gradient = grad
	add_child(_trail)

func _create_item_trail() -> void:
	_item_trail = Line2D.new()
	_item_trail.width = 8.0
	_item_trail.default_color = Color(0, 1, 0.5, 0.7)
	_item_trail.top_level = true
	_item_trail.z_index = -1
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 1, 0.5, 0))
	grad.set_color(1, Color(0, 1, 0.5, 0.7))
	_item_trail.gradient = grad
	add_child(_item_trail)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		use_mouse_steer = true
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		use_mouse_steer = false
	elif event is InputEventKey:
		if event.physical_keycode in [KEY_A, KEY_D]:
			use_mouse_steer = false

func _physics_process(delta: float) -> void:
	if not race_started:
		return

	_read_input(delta)
	_apply_physics(delta)
	move_and_slide()

	current_speed = velocity.length()
	speed_changed.emit(current_speed)
	_update_visuals(delta)
	_update_item_boost(delta)

func _read_input(delta: float) -> void:
	var kb_steer := Input.get_axis("steer_left", "steer_right")
	if abs(kb_steer) > 0.05:
		use_mouse_steer = false

	if use_mouse_steer:
		mouse_world_pos = get_global_mouse_position()
		var to_mouse := mouse_world_pos - global_position
		if to_mouse.length() > 30.0:
			var target_angle := to_mouse.angle() + PI / 2.0
			var angle_diff := wrapf(target_angle - rotation, -PI, PI)
			steer_input = clampf(angle_diff / (PI * 0.5), -1.0, 1.0)
		else:
			steer_input = 0.0
	else:
		steer_input = kb_steer

	throttle_input = Input.get_action_strength("accelerate")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		throttle_input = maxf(throttle_input, 1.0)
		use_mouse_steer = true

	brake_input = Input.get_action_strength("brake")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		brake_input = maxf(brake_input, 1.0)

	var jump_strength := Input.get_action_strength("jump")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		jump_strength = maxf(jump_strength, 1.0)
	var was_held := jump_held
	jump_held = jump_strength > 0.15

	if jump_held and not was_held and current_speed > min_jump_speed:
		_do_hop()
		is_jumping = true
		drift_time = 0.0
		charge_ratio = 0.0

	if jump_held and is_jumping:
		drift_time += delta
		charge_ratio = clampf(drift_time / charge_full_time, 0.0, 1.0)

	if not jump_held and was_held and is_jumping:
		_do_boost()
		is_jumping = false
		drift_time = 0.0
		charge_ratio = 0.0

	# Use item boost
	if Input.is_action_just_pressed("use_item") and has_item:
		_activate_item_boost()

	if Input.is_action_just_pressed("reset"):
		reset_to_spawn()

func _do_hop() -> void:
	if is_hopping:
		return
	is_hopping = true
	_shadow.visible = true
	# Disable jump-wall collision while hopping
	set_collision_mask_value(jump_wall_layer, false)

	if _hop_tween:
		_hop_tween.kill()

	_hop_tween = create_tween()
	_hop_tween.tween_property(_car_sprite, "scale", Vector2(hop_scale, hop_scale), hop_duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hop_tween.parallel().tween_property(_nose_sprite, "scale", Vector2(hop_scale, hop_scale), hop_duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hop_tween.parallel().tween_property(_car_sprite, "position", Vector2(0, -22), hop_duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hop_tween.parallel().tween_property(_nose_sprite, "position", Vector2(0, -22), hop_duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_hop_tween.tween_property(_car_sprite, "scale", Vector2.ONE, hop_duration * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	_hop_tween.parallel().tween_property(_nose_sprite, "scale", Vector2.ONE, hop_duration * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	_hop_tween.parallel().tween_property(_car_sprite, "position", Vector2.ZERO, hop_duration * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	_hop_tween.parallel().tween_property(_nose_sprite, "position", Vector2.ZERO, hop_duration * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)

	_hop_tween.tween_callback(func():
		is_hopping = false
		_shadow.visible = false
		# Re-enable jump-wall collision on landing (only if not still holding jump)
		if not jump_held:
			set_collision_mask_value(jump_wall_layer, true)
	)

func _do_boost() -> void:
	# Re-enable jump walls on boost release
	set_collision_mask_value(jump_wall_layer, true)

	var boost_power := minf(boost_base + boost_per_second * drift_time, boost_max)
	var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
	velocity = forward_dir * (current_speed + boost_power)

	is_boosting = true
	boost_timer = TRAIL_DURATION
	_trail.clear_points()

	if _hop_tween:
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_property(_car_sprite, "scale", Vector2(1.2, 1.2), 0.06)
	_hop_tween.parallel().tween_property(_nose_sprite, "scale", Vector2(1.2, 1.2), 0.06)
	_hop_tween.tween_property(_car_sprite, "scale", Vector2.ONE, 0.2)
	_hop_tween.parallel().tween_property(_nose_sprite, "scale", Vector2.ONE, 0.2)

func _activate_item_boost() -> void:
	has_item = false
	item_boost_active = true
	item_boost_timer = item_boost_duration
	_item_trail.clear_points()

func _update_item_boost(delta: float) -> void:
	if item_boost_active:
		item_boost_timer -= delta
		# Add speed boost
		var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
		velocity += forward_dir * item_boost_speed * delta
		# Green trail
		var rear := global_position + Vector2.from_angle(rotation - PI / 2.0) * -20.0
		_item_trail.add_point(rear)
		if _item_trail.get_point_count() > 20:
			_item_trail.remove_point(0)
		if item_boost_timer <= 0.0:
			item_boost_active = false

	if not item_boost_active and _item_trail.get_point_count() > 0:
		_trail_timer += delta
		if _trail_timer > 0.03:
			_trail_timer = 0.0
			_item_trail.remove_point(0)

func collect_item() -> void:
	has_item = true

func _update_visuals(delta: float) -> void:
	if is_jumping and jump_held:
		var charge_color: Color
		if charge_ratio < 0.5:
			charge_color = color_normal.lerp(color_charge_mid, charge_ratio * 2.0)
		else:
			charge_color = color_charge_mid.lerp(color_charge_full, (charge_ratio - 0.5) * 2.0)
		_car_sprite.color = charge_color
		if charge_ratio >= 1.0:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
			_nose_sprite.color = color_charge_full.lerp(Color.WHITE, pulse * 0.4)
		else:
			_nose_sprite.color = charge_color.lightened(0.3)
	elif is_boosting:
		_car_sprite.color = color_charge_full
		_nose_sprite.color = Color(1, 0.5, 0.2, 1)
	elif item_boost_active:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		_car_sprite.color = color_normal.lerp(color_item_boost, pulse)
		_nose_sprite.color = color_item_boost
	else:
		_car_sprite.color = _car_sprite.color.lerp(color_normal, delta * 6.0)
		_nose_sprite.color = _nose_sprite.color.lerp(color_nose_normal, delta * 6.0)

	# Boost trail
	if is_boosting:
		boost_timer -= delta
		var rear_offset := Vector2.from_angle(rotation - PI / 2.0) * -25.0
		_trail.add_point(global_position + rear_offset)
		if _trail.get_point_count() > TRAIL_MAX_POINTS:
			_trail.remove_point(0)
		if boost_timer <= 0.0:
			is_boosting = false

	if not is_boosting and _trail.get_point_count() > 0:
		_trail_timer += delta
		if _trail_timer > 0.02:
			_trail_timer = 0.0
			_trail.remove_point(0)

func _apply_physics(delta: float) -> void:
	var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
	var forward_speed := velocity.dot(forward_dir)

	var effective_max := max_speed
	if item_boost_active:
		effective_max *= 1.5

	if throttle_input > 0.0:
		if forward_speed < effective_max:
			velocity += forward_dir * acceleration * throttle_input * delta
	if brake_input > 0.0:
		if forward_speed > -reverse_max_speed:
			velocity -= forward_dir * brake_force * brake_input * delta

	var was_drifting := is_drifting
	is_drifting = is_jumping and jump_held and abs(steer_input) > 0.05 and current_speed > min_jump_speed

	if is_drifting != was_drifting:
		drift_state_changed.emit(is_drifting)

	if is_jumping and jump_held:
		velocity -= velocity.normalized() * drift_decel * delta
		if velocity.length() < 20.0:
			velocity = velocity.normalized() * 20.0

	var target_traction := drift_traction if (is_jumping and jump_held) else base_traction
	current_traction = lerp(current_traction, target_traction, traction_transition_speed * delta)

	var right_dir := Vector2.from_angle(rotation)
	forward_speed = velocity.dot(forward_dir)
	var lateral_speed := velocity.dot(right_dir)
	lateral_speed = lerp(lateral_speed, 0.0, current_traction)
	velocity = forward_dir * forward_speed + right_dir * lateral_speed
	velocity *= drag

	if velocity.length() > 10.0:
		var speed_factor := clampf(current_speed / (effective_max * 0.3), 0.0, 1.0)
		speed_factor = pow(speed_factor, steering_curve)

		var steer_amount: float
		if use_mouse_steer:
			steer_amount = steer_input * mouse_steer_speed * speed_factor * delta
		else:
			steer_amount = steer_input * steering_speed * speed_factor * delta

		if is_drifting:
			steer_amount *= drift_steer_multiplier

		rotation += steer_amount

func reset_to_spawn() -> void:
	global_position = spawn_position
	rotation = spawn_rotation
	velocity = Vector2.ZERO
	current_speed = 0.0
	is_drifting = false
	is_jumping = false
	jump_held = false
	drift_time = 0.0
	charge_ratio = 0.0
	is_boosting = false
	boost_timer = 0.0
	item_boost_active = false
	item_boost_timer = 0.0
	current_traction = base_traction
	collision_mask = _original_collision_mask
	_car_sprite.color = color_normal
	_nose_sprite.color = color_nose_normal
	_trail.clear_points()
	_item_trail.clear_points()
	if _hop_tween:
		_hop_tween.kill()
	is_hopping = false
	_shadow.visible = false
	_car_sprite.scale = Vector2.ONE
	_nose_sprite.scale = Vector2.ONE
	_car_sprite.position = Vector2.ZERO
	_nose_sprite.position = Vector2.ZERO

func start_race() -> void:
	race_started = true

func stop_race() -> void:
	race_started = false
