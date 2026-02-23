extends CharacterBody2D

signal speed_changed(speed: float)
signal drift_state_changed(is_drifting: bool)
signal missile_fired(spawn_pos: Vector2, direction: Vector2, source_car: CharacterBody2D)

# -- Player ID --
@export var player_id: int = 1
@export var car_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var ai_controlled: bool = false

# -- Movement --
@export var acceleration: float = GameConstants.CAR_ACCELERATION
@export var max_speed: float = GameConstants.CAR_MAX_SPEED
@export var brake_force: float = GameConstants.CAR_BRAKE_FORCE
@export var reverse_max_speed: float = GameConstants.CAR_REVERSE_MAX_SPEED
@export var drag: float = GameConstants.CAR_DRAG

# -- Steering --
@export var steering_speed: float = GameConstants.CAR_STEERING_SPEED
@export var steering_curve: float = GameConstants.CAR_STEERING_CURVE
@export var mouse_steer_speed: float = GameConstants.CAR_MOUSE_STEER_SPEED

# -- Traction --
@export var base_traction: float = GameConstants.CAR_BASE_TRACTION
@export var traction_transition_speed: float = GameConstants.CAR_TRACTION_TRANSITION_SPEED

# -- Drift (separate from jump) --
@export var drift_traction: float = GameConstants.DRIFT_TRACTION
@export var drift_steer_multiplier: float = GameConstants.DRIFT_STEER_MULTIPLIER
@export var drift_min_speed: float = GameConstants.DRIFT_MIN_SPEED
@export var drift_speed_decay: float = GameConstants.DRIFT_SPEED_DECAY
@export var drift_charge_full_time: float = GameConstants.DRIFT_CHARGE_FULL_TIME
@export var drift_boost_base: float = GameConstants.DRIFT_BOOST_BASE
@export var drift_boost_per_second: float = GameConstants.DRIFT_BOOST_PER_SECOND
@export var drift_boost_max: float = GameConstants.DRIFT_BOOST_MAX
@export var drift_min_angle: float = GameConstants.DRIFT_MIN_ANGLE
@export var drift_min_hold: float = GameConstants.DRIFT_MIN_HOLD

# -- Jump (one-shot arc) --
@export var jump_height: float = GameConstants.JUMP_HEIGHT
@export var jump_ascent_time: float = GameConstants.JUMP_ASCENT_TIME
@export var jump_descent_time: float = GameConstants.JUMP_DESCENT_TIME
@export var jump_cooldown: float = GameConstants.JUMP_COOLDOWN
@export var jump_min_speed: float = GameConstants.JUMP_MIN_SPEED
@export var jump_air_drag: float = GameConstants.JUMP_AIR_DRAG
@export var jump_air_steer_mult: float = GameConstants.JUMP_AIR_STEER_MULT
## Collision layer for jump-only walls (car ignores these while airborne)
@export var jump_wall_layer: int = GameConstants.JUMP_WALL_LAYER

# -- Item boost --
@export var item_boost_speed: float = GameConstants.ITEM_BOOST_SPEED
@export var item_boost_duration: float = GameConstants.ITEM_BOOST_DURATION

# -- Missiles --
var missile_count: int = 0
var _missile_side: int = 0  # alternates 0/1 for left/right headlight

# -- Colors --
var color_normal := Color(0.2, 0.6, 1.0, 1.0)
var color_charge_mid := Color(1.0, 0.55, 0.0, 1.0)
var color_charge_full := Color(1.0, 0.15, 0.0, 1.0)
var color_nose_normal := Color(1.0, 0.9, 0.2, 1.0)
var color_item_boost := Color(0.0, 1.0, 0.5, 1.0)

# -- State --
var current_speed: float = 0.0
var current_traction: float = 0.85
var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var use_mouse_steer: bool = false
var mouse_world_pos: Vector2 = Vector2.ZERO

# Drift state
var drift_held: bool = false
var is_drift_sliding: bool = false
var drift_charge_time: float = 0.0
var drift_charge_ratio: float = 0.0
var is_drifting: bool = false

# Jump-drift queue
var _drift_queued: bool = false

# Jump state
var jump_airborne: bool = false
var _jump_cooldown_timer: float = 0.0
var _jump_tween: Tween = null

# Boost trail state
var is_boosting: bool = false
var boost_timer: float = 0.0

# Item boost state
var has_item: bool = false
var item_boost_active: bool = false
var item_boost_timer: float = 0.0

# Hit stun state
var hit_stun_timer: float = 0.0
var _hit_spin_speed: float = 0.0

var spawn_position: Vector2 = Vector2.ZERO
var spawn_rotation: float = 0.0
var race_started: bool = false
var _original_collision_mask: int = 0

# AI virtual inputs (written by ai_controller.gd)
var ai_steer: float = 0.0
var ai_throttle: float = 0.0
var ai_brake: float = 0.0
var ai_jump_pressed: bool = false
var ai_drift_strength: float = 0.0
var ai_use_item_pressed: bool = false
var ai_fire_missile_pressed: bool = false

var _car_sprite: Polygon2D = null
var _nose_sprite: Polygon2D = null
var _shadow: Polygon2D = null
var _trail: Line2D = null
var _trail_timer: float = 0.0
var _item_trail: Line2D = null
var _drift_trail_l: Line2D = null
var _drift_trail_r: Line2D = null
const TRAIL_DURATION := 0.6
const TRAIL_MAX_POINTS := 30

func _action(base_name: String) -> String:
	if player_id == 2:
		return "p2_" + base_name
	return base_name

func _ready() -> void:
	spawn_position = global_position
	spawn_rotation = rotation
	_car_sprite = $CarSprite
	_nose_sprite = $NoseIndicator
	_original_collision_mask = collision_mask
	color_normal = car_color
	_car_sprite.color = car_color
	_create_shadow()
	_create_trail()
	_create_item_trail()
	_create_drift_trails()

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

func _create_drift_trails() -> void:
	for i in 2:
		var t := Line2D.new()
		t.width = 4.0
		t.default_color = Color(0.3, 0.3, 0.3, 0.6)
		t.top_level = true
		t.z_index = -1
		add_child(t)
		if i == 0:
			_drift_trail_l = t
		else:
			_drift_trail_r = t

func _unhandled_input(event: InputEvent) -> void:
	if player_id != 1:
		return
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

	if hit_stun_timer > 0.0:
		_process_stun(delta)
		move_and_slide()
		current_speed = velocity.length()
		_update_visuals(delta)
		return

	_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)
	_read_input(delta)
	_apply_physics(delta)
	move_and_slide()

	current_speed = velocity.length()
	speed_changed.emit(current_speed)
	_update_visuals(delta)
	_update_item_boost(delta)
	_update_drift_trails()

func _read_input(delta: float) -> void:
	if ai_controlled:
		# AI path — read from ai_* vars set by ai_controller.gd
		steer_input = ai_steer
		throttle_input = ai_throttle
		brake_input = ai_brake

		if ai_jump_pressed and not jump_airborne and _jump_cooldown_timer <= 0.0 and current_speed > jump_min_speed:
			_do_jump()
		ai_jump_pressed = false

		_process_drift_input(delta, ai_drift_strength)

		if ai_use_item_pressed and has_item:
			_activate_item_boost()
		ai_use_item_pressed = false

		if ai_fire_missile_pressed and missile_count > 0:
			_fire_missile()
		ai_fire_missile_pressed = false
		return

	# -- Steering --
	var kb_steer := Input.get_axis(_action("steer_left"), _action("steer_right"))
	if abs(kb_steer) > 0.05 and player_id == 1:
		use_mouse_steer = false

	if use_mouse_steer and player_id == 1:
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

	# -- Throttle / Brake --
	throttle_input = Input.get_action_strength(_action("accelerate"))
	if player_id == 1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		throttle_input = maxf(throttle_input, 1.0)
		use_mouse_steer = true

	brake_input = Input.get_action_strength(_action("brake"))
	if player_id == 1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		brake_input = maxf(brake_input, 1.0)

	# -- Jump (one-shot press) --
	if Input.is_action_just_pressed(_action("jump")) and not jump_airborne and _jump_cooldown_timer <= 0.0 and current_speed > jump_min_speed:
		_do_jump()

	# -- Drift --
	var drift_strength := Input.get_action_strength(_action("drift"))
	if player_id == 1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		drift_strength = maxf(drift_strength, 1.0)
	_process_drift_input(delta, drift_strength)

	# -- Use item boost --
	if Input.is_action_just_pressed(_action("use_item")) and has_item:
		_activate_item_boost()

	# -- Fire missile --
	if Input.is_action_just_pressed(_action("fire_missile")) and missile_count > 0:
		_fire_missile()

	# -- Reset --
	if Input.is_action_just_pressed(_action("reset")):
		reset_to_spawn()

func _process_drift_input(delta: float, drift_strength_val: float) -> void:
	var was_drift_held := drift_held
	drift_held = drift_strength_val > 0.15

	if drift_held and not was_drift_held and current_speed > drift_min_speed:
		if jump_airborne:
			_drift_queued = true
		else:
			is_drift_sliding = true
			drift_charge_time = 0.0
			drift_charge_ratio = 0.0

	if _drift_queued and not drift_held:
		_drift_queued = false

	if is_drift_sliding:
		if current_speed < drift_min_speed * 0.5 or not drift_held:
			if drift_held:
				is_drift_sliding = false
				drift_charge_time = 0.0
				drift_charge_ratio = 0.0
			else:
				_do_drift_boost()
				is_drift_sliding = false
				drift_charge_time = 0.0
				drift_charge_ratio = 0.0
		elif abs(steer_input) > drift_min_angle:
			drift_charge_time += delta
			drift_charge_ratio = clampf(drift_charge_time / drift_charge_full_time, 0.0, 1.0)

	var was_drifting := is_drifting
	is_drifting = is_drift_sliding and abs(steer_input) > drift_min_angle
	if is_drifting != was_drifting:
		drift_state_changed.emit(is_drifting)

func _do_jump() -> void:
	jump_airborne = true
	_drift_queued = false
	_shadow.visible = true
	set_collision_mask_value(jump_wall_layer, false)

	# Cancel any active drift
	if is_drift_sliding:
		is_drift_sliding = false
		drift_charge_time = 0.0
		drift_charge_ratio = 0.0
		is_drifting = false

	if _jump_tween:
		_jump_tween.kill()

	_jump_tween = create_tween()

	# Ascent: scale up, sprite rises
	_jump_tween.tween_property(_car_sprite, "scale", Vector2(jump_height, jump_height), jump_ascent_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_jump_tween.parallel().tween_property(_nose_sprite, "scale", Vector2(jump_height, jump_height), jump_ascent_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_jump_tween.parallel().tween_property(_car_sprite, "position", Vector2(0, -60), jump_ascent_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_jump_tween.parallel().tween_property(_nose_sprite, "position", Vector2(0, -60), jump_ascent_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Shadow grows and fades during ascent
	_jump_tween.parallel().tween_property(_shadow, "scale", Vector2(1.5, 1.5), jump_ascent_time)
	_jump_tween.parallel().tween_property(_shadow, "modulate", Color(1, 1, 1, 0.15), jump_ascent_time)

	# Brief hang at apex
	_jump_tween.tween_interval(0.05)

	# Descent: heavier fall with landing squash
	_jump_tween.tween_property(_car_sprite, "scale", Vector2(1.15, 0.9), jump_descent_time * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_jump_tween.parallel().tween_property(_nose_sprite, "scale", Vector2(1.15, 0.9), jump_descent_time * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_jump_tween.parallel().tween_property(_car_sprite, "position", Vector2(0, 4), jump_descent_time * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_jump_tween.parallel().tween_property(_nose_sprite, "position", Vector2(0, 4), jump_descent_time * 0.7)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_jump_tween.parallel().tween_property(_shadow, "scale", Vector2(1.0, 1.0), jump_descent_time * 0.7)
	_jump_tween.parallel().tween_property(_shadow, "modulate", Color(1, 1, 1, 0.35), jump_descent_time * 0.7)

	# Settle back to normal with bounce
	_jump_tween.tween_property(_car_sprite, "scale", Vector2.ONE, jump_descent_time * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_jump_tween.parallel().tween_property(_nose_sprite, "scale", Vector2.ONE, jump_descent_time * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_jump_tween.parallel().tween_property(_car_sprite, "position", Vector2.ZERO, jump_descent_time * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_jump_tween.parallel().tween_property(_nose_sprite, "position", Vector2.ZERO, jump_descent_time * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

	# Landing callback
	_jump_tween.tween_callback(func():
		jump_airborne = false
		_shadow.visible = false
		_shadow.scale = Vector2.ONE
		_shadow.modulate = Color(1, 1, 1, 0.35)
		set_collision_mask_value(jump_wall_layer, true)
		_jump_cooldown_timer = jump_cooldown
		# Activate queued drift from mid-air input
		if _drift_queued and drift_held and current_speed > drift_min_speed:
			is_drift_sliding = true
			drift_charge_time = 0.0
			drift_charge_ratio = 0.0
		_drift_queued = false
	)

func _do_drift_boost() -> void:
	if drift_charge_time < drift_min_hold:
		return

	var boost_power := minf(drift_boost_base + drift_boost_per_second * drift_charge_time, drift_boost_max)
	var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
	velocity = forward_dir * (current_speed + boost_power)

	is_boosting = true
	boost_timer = TRAIL_DURATION
	_trail.clear_points()

	if _jump_tween:
		_jump_tween.kill()
	_jump_tween = create_tween()
	_jump_tween.tween_property(_car_sprite, "scale", Vector2(1.2, 1.2), 0.06)
	_jump_tween.parallel().tween_property(_nose_sprite, "scale", Vector2(1.2, 1.2), 0.06)
	_jump_tween.tween_property(_car_sprite, "scale", Vector2.ONE, 0.2)
	_jump_tween.parallel().tween_property(_nose_sprite, "scale", Vector2.ONE, 0.2)

func _activate_item_boost() -> void:
	has_item = false
	item_boost_active = true
	item_boost_timer = item_boost_duration
	_item_trail.clear_points()

func _update_item_boost(delta: float) -> void:
	if item_boost_active:
		item_boost_timer -= delta
		var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
		velocity += forward_dir * item_boost_speed * delta
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

func collect_missiles(count: int) -> void:
	missile_count += count

func _fire_missile() -> void:
	print("[Combat] P%d fired missile (remaining: %d)" % [player_id, missile_count - 1])
	missile_count -= 1
	var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
	# Alternate left/right headlight offset
	var side_offset := 10.0 if _missile_side == 0 else -10.0
	_missile_side = 1 - _missile_side
	var right_dir := Vector2.from_angle(rotation)
	var spawn_pos := global_position + forward_dir * 30.0 + right_dir * side_offset
	missile_fired.emit(spawn_pos, forward_dir, self)

func hit_by_missile(dir: Vector2) -> void:
	hit_stun_timer = GameConstants.STUN_DURATION
	_hit_spin_speed = GameConstants.STUN_SPIN_SPEED
	velocity *= GameConstants.STUN_VELOCITY_RETAIN
	velocity += dir * GameConstants.STUN_KNOCKBACK
	# Kill jump tween and reset airborne if stunned mid-air
	if jump_airborne:
		if _jump_tween:
			_jump_tween.kill()
		jump_airborne = false
		_shadow.visible = false
		_shadow.scale = Vector2.ONE
		_shadow.modulate = Color(1, 1, 1, 0.35)
		_car_sprite.scale = Vector2.ONE
		_nose_sprite.scale = Vector2.ONE
		_car_sprite.position = Vector2.ZERO
		_nose_sprite.position = Vector2.ZERO
		set_collision_mask_value(jump_wall_layer, true)
	# Red flash
	_car_sprite.color = Color(1, 0.1, 0.1, 1)
	_nose_sprite.color = Color(1, 0.1, 0.1, 1)
	# Cancel drift
	is_drift_sliding = false
	drift_charge_time = 0.0
	drift_charge_ratio = 0.0
	is_drifting = false
	_drift_queued = false

func _process_stun(delta: float) -> void:
	hit_stun_timer -= delta
	rotation += _hit_spin_speed * delta
	_hit_spin_speed *= 0.95
	velocity *= 0.95
	if hit_stun_timer <= 0.0:
		hit_stun_timer = 0.0
		_car_sprite.color = color_normal
		_nose_sprite.color = color_nose_normal

func _update_drift_trails() -> void:
	if is_drift_sliding:
		var right := Vector2.from_angle(rotation)
		var rear := Vector2.from_angle(rotation - PI / 2.0) * -20.0
		var lw := global_position + rear + right * -10.0
		var rw := global_position + rear + right * 10.0
		_drift_trail_l.add_point(lw)
		_drift_trail_r.add_point(rw)
		if _drift_trail_l.get_point_count() > 40:
			_drift_trail_l.remove_point(0)
		if _drift_trail_r.get_point_count() > 40:
			_drift_trail_r.remove_point(0)
	else:
		# Fade out drift trails
		if _drift_trail_l.get_point_count() > 0:
			_drift_trail_l.remove_point(0)
		if _drift_trail_r.get_point_count() > 0:
			_drift_trail_r.remove_point(0)

func _update_visuals(delta: float) -> void:
	# Drift charge color
	if is_drift_sliding and drift_charge_ratio > 0.0:
		var charge_color: Color
		if drift_charge_ratio < 0.5:
			charge_color = color_normal.lerp(color_charge_mid, drift_charge_ratio * 2.0)
		else:
			charge_color = color_charge_mid.lerp(color_charge_full, (drift_charge_ratio - 0.5) * 2.0)
		_car_sprite.color = charge_color
		if drift_charge_ratio >= 1.0:
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
	elif hit_stun_timer > 0.0:
		var flash := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		_car_sprite.color = Color(1, flash * 0.3, flash * 0.3, 1)
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
		effective_max *= GameConstants.ITEM_BOOST_MAX_SPEED_MULT

	# While airborne: maintain momentum, minimal drag, reduced steering
	if jump_airborne:
		velocity *= jump_air_drag
		if velocity.length() > 10.0:
			var speed_factor := clampf(current_speed / (effective_max * 0.3), 0.0, 1.0)
			speed_factor = pow(speed_factor, steering_curve)
			var steer_amount := steer_input * steering_speed * speed_factor * delta
			rotation += steer_amount * jump_air_steer_mult
		return

	# Acceleration / braking
	if throttle_input > 0.0:
		if forward_speed < effective_max:
			velocity += forward_dir * acceleration * throttle_input * delta
	if brake_input > 0.0:
		if forward_speed > -reverse_max_speed:
			velocity -= forward_dir * brake_force * brake_input * delta

	# Drift physics (delta-scaled decay for framerate independence)
	if is_drift_sliding:
		velocity *= pow(drift_speed_decay, delta * 60.0)

	var target_traction := drift_traction if is_drift_sliding else base_traction
	current_traction = lerp(current_traction, target_traction, traction_transition_speed * delta)

	var right_dir := Vector2.from_angle(rotation)
	forward_speed = velocity.dot(forward_dir)
	var lateral_speed := velocity.dot(right_dir)
	# Delta-scaled traction so grip is framerate-independent
	var traction_factor := 1.0 - pow(1.0 - current_traction, delta * 60.0)
	lateral_speed = lerp(lateral_speed, 0.0, traction_factor)
	velocity = forward_dir * forward_speed + right_dir * lateral_speed
	velocity *= drag
	# Absolute speed cap prevents infinite stacking from drift + item boost
	if velocity.length() > GameConstants.ABSOLUTE_MAX_SPEED:
		velocity = velocity.normalized() * GameConstants.ABSOLUTE_MAX_SPEED

	# Steering (skip while airborne — already returned above)
	if velocity.length() > 10.0:
		var speed_factor := clampf(current_speed / (effective_max * 0.3), 0.0, 1.0)
		speed_factor = pow(speed_factor, steering_curve)

		var steer_amount: float
		if use_mouse_steer and player_id == 1:
			steer_amount = steer_input * mouse_steer_speed * speed_factor * delta
		else:
			steer_amount = steer_input * steering_speed * speed_factor * delta

		if is_drift_sliding:
			steer_amount *= drift_steer_multiplier

		rotation += steer_amount

func reset_to_spawn() -> void:
	print("[Race] P%d reset to spawn" % player_id)
	global_position = spawn_position
	rotation = spawn_rotation
	velocity = Vector2.ZERO
	current_speed = 0.0
	is_drifting = false
	is_drift_sliding = false
	drift_held = false
	drift_charge_time = 0.0
	drift_charge_ratio = 0.0
	jump_airborne = false
	_drift_queued = false
	_jump_cooldown_timer = 0.0
	is_boosting = false
	boost_timer = 0.0
	item_boost_active = false
	item_boost_timer = 0.0
	hit_stun_timer = 0.0
	missile_count = 0
	has_item = false
	current_traction = base_traction
	collision_mask = _original_collision_mask
	_car_sprite.color = color_normal
	_nose_sprite.color = color_nose_normal
	_trail.clear_points()
	_item_trail.clear_points()
	_drift_trail_l.clear_points()
	_drift_trail_r.clear_points()
	if _jump_tween:
		_jump_tween.kill()
	_shadow.visible = false
	_shadow.scale = Vector2.ONE
	_shadow.modulate = Color(1, 1, 1, 0.35)
	_car_sprite.scale = Vector2.ONE
	_nose_sprite.scale = Vector2.ONE
	_car_sprite.position = Vector2.ZERO
	_nose_sprite.position = Vector2.ZERO

func start_race() -> void:
	race_started = true

func stop_race() -> void:
	race_started = false
