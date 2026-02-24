extends CharacterBody2D

signal speed_changed(speed: float)
signal drift_state_changed(is_drifting: bool)
signal drift_started()
signal drift_tier_changed(tier: int)
signal drift_released(boost_strength: float)
signal missile_fired(spawn_pos: Vector2, direction: Vector2, source_car: CharacterBody2D, locked: bool)

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

# -- Drift --
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

# -- Item boost --
@export var item_boost_speed: float = GameConstants.ITEM_BOOST_SPEED
@export var item_boost_duration: float = GameConstants.ITEM_BOOST_DURATION

# -- Missiles --
var missile_count: int = 0
var _missile_side: int = 0  # alternates 0/1 for left/right headlight

# -- Missile Sprites --
var _missile_sprite_l: Polygon2D = null
var _missile_sprite_r: Polygon2D = null
var _missile_bob_time: float = 0.0

# -- Targeting --
enum TargetingState { IDLE, SEEKING, LOCKED }
var targeting_state: int = TargetingState.IDLE
var _targeting_timer: float = 0.0
var _target_car: CharacterBody2D = null
var _reticle_node: Node2D = null
var _reticle_pos: Vector2 = Vector2.ZERO
var _reticle_locked: bool = false
var _reticle_ring: Polygon2D = null
var _reticle_dot: Polygon2D = null
var _reticle_spin: float = 0.0

# -- Colors --
var color_normal := Color(0.2, 0.6, 1.0, 1.0)
var color_charge_mid := Color(1.0, 0.55, 0.0, 1.0)
var color_charge_full := Color(1.0, 0.15, 0.0, 1.0)
var color_charge_max := Color(0.7, 0.2, 1.0, 1.0)  # Tier 3 purple
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

# Drift state machine
enum DriftState { NONE, SLIDING, BOOSTING }
var drift_state: int = DriftState.NONE
var drift_held: bool = false
var is_drift_sliding: bool = false
var drift_charge_time: float = 0.0
var drift_charge_ratio: float = 0.0
var is_drifting: bool = false
var drift_tier: int = 0
var drift_direction: float = 0.0

# Boost trail state
var is_boosting: bool = false
var boost_timer: float = 0.0

# Post-boost linger (reduced drag after boost)
var _boost_linger_timer: float = 0.0

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
var wall_hit_count: int = 0

# AI virtual inputs (written by ai_controller.gd)
var ai_steer: float = 0.0
var ai_throttle: float = 0.0
var ai_brake: float = 0.0
var ai_drift_strength: float = 0.0
var ai_use_item_pressed: bool = false
var ai_fire_missile_pressed: bool = false

var _car_sprite: Polygon2D = null
var _nose_sprite: Polygon2D = null
var _trail: Line2D = null
var _trail_timer: float = 0.0
var _item_trail: Line2D = null
var _drift_trail_l: Line2D = null
var _drift_trail_r: Line2D = null
var _spark_l: GPUParticles2D = null
var _spark_r: GPUParticles2D = null
const TRAIL_DURATION := 0.6
const TRAIL_MAX_POINTS := 30
const SPARK_LIFETIME := 0.25
const SPARK_AMOUNT := 8
const SPARK_SPEED := 200.0

# Tween for boost pop animation
var _boost_tween: Tween = null

func _action(base_name: String) -> String:
	if player_id == 2:
		return "p2_" + base_name
	return base_name

func _ready() -> void:
	spawn_position = global_position
	spawn_rotation = rotation
	_car_sprite = $CarSprite
	_nose_sprite = $NoseIndicator
	color_normal = car_color
	_car_sprite.color = car_color
	_create_trail()
	_create_item_trail()
	_create_drift_trails()
	_create_spark_emitters()
	_create_missile_sprites()
	_create_reticle()

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

func _create_spark_emitters() -> void:
	for i in 2:
		var p := GPUParticles2D.new()
		p.emitting = false
		p.amount = SPARK_AMOUNT
		p.lifetime = SPARK_LIFETIME
		p.one_shot = false
		p.explosiveness = 0.8
		p.z_index = 1
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 35.0
		mat.initial_velocity_min = SPARK_SPEED * 0.75
		mat.initial_velocity_max = SPARK_SPEED
		mat.gravity = Vector3(0, 120, 0)
		mat.scale_min = 2.0
		mat.scale_max = 4.0
		mat.color = Color(0.3, 0.3, 0.3, 0.6)
		p.process_material = mat
		add_child(p)
		if i == 0:
			_spark_l = p
		else:
			_spark_r = p

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

	_read_input(delta)
	_apply_physics(delta)
	move_and_slide()

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision:
			wall_hit_count += 1

	current_speed = velocity.length()
	speed_changed.emit(current_speed)
	_update_visuals(delta)
	_update_item_boost(delta)
	_update_drift_trails()
	_update_missile_sprites(delta)
	if targeting_state != TargetingState.IDLE:
		_update_targeting(delta)

func _read_input(delta: float) -> void:
	if ai_controlled:
		# AI path — read from ai_* vars set by ai_controller.gd
		steer_input = ai_steer
		throttle_input = ai_throttle
		brake_input = ai_brake

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

	# -- Drift --
	var drift_strength := Input.get_action_strength(_action("drift"))
	if player_id == 1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		drift_strength = maxf(drift_strength, 1.0)
	_process_drift_input(delta, drift_strength)

	# -- Use item boost --
	if Input.is_action_just_pressed(_action("use_item")) and has_item:
		_activate_item_boost()

	# -- Fire missile (two-press targeting) --
	if Input.is_action_just_pressed(_action("fire_missile")):
		if targeting_state == TargetingState.IDLE:
			if missile_count > 0:
				_begin_targeting()
		else:
			_fire_missile_targeted()

	# -- Reset --
	if Input.is_action_just_pressed(_action("reset")):
		reset_to_spawn()

func _process_drift_input(delta: float, drift_strength_val: float) -> void:
	var was_drift_held := drift_held
	drift_held = drift_strength_val > 0.15

	match drift_state:
		DriftState.NONE:
			if drift_held and not was_drift_held and current_speed > drift_min_speed:
				# Enter SLIDING state
				drift_state = DriftState.SLIDING
				is_drift_sliding = true
				drift_charge_time = 0.0
				drift_charge_ratio = 0.0
				drift_tier = 0
				drift_direction = signf(steer_input) if abs(steer_input) > 0.1 else 0.0
				drift_started.emit()

		DriftState.SLIDING:
			if current_speed < drift_min_speed * 0.5:
				# Speed too low — cancel drift, no boost
				_cancel_drift()
			elif not drift_held:
				# Released — transition to BOOSTING
				drift_state = DriftState.BOOSTING
				_do_drift_boost()
				_end_drift_state()
			else:
				# Still holding — accumulate charge
				if abs(steer_input) > drift_min_angle:
					drift_charge_time += delta
					drift_charge_ratio = clampf(drift_charge_time / drift_charge_full_time, 0.0, 1.0)

				# Update drift tier
				var new_tier := 0
				if drift_charge_time >= GameConstants.DRIFT_TIER_3_TIME:
					new_tier = 3
				elif drift_charge_time >= GameConstants.DRIFT_TIER_2_TIME:
					new_tier = 2
				elif drift_charge_time >= GameConstants.DRIFT_TIER_1_TIME:
					new_tier = 1

				if new_tier != drift_tier:
					drift_tier = new_tier
					drift_tier_changed.emit(drift_tier)

		DriftState.BOOSTING:
			# Immediate transition back to NONE (boost applied in _do_drift_boost)
			drift_state = DriftState.NONE

	# Backward compat for UI reads
	var was_drifting := is_drifting
	is_drifting = is_drift_sliding and abs(steer_input) > drift_min_angle
	if is_drifting != was_drifting:
		drift_state_changed.emit(is_drifting)

func _cancel_drift() -> void:
	drift_state = DriftState.NONE
	is_drift_sliding = false
	drift_charge_time = 0.0
	drift_charge_ratio = 0.0
	drift_tier = 0
	drift_direction = 0.0
	is_drifting = false
	if _spark_l:
		_spark_l.emitting = false
	if _spark_r:
		_spark_r.emitting = false

func _end_drift_state() -> void:
	is_drift_sliding = false
	drift_charge_time = 0.0
	drift_charge_ratio = 0.0
	drift_tier = 0
	drift_direction = 0.0
	is_drifting = false

func _do_drift_boost() -> void:
	if drift_charge_time < drift_min_hold:
		drift_state = DriftState.NONE
		return

	# Tier multiplier: Tier 1 = 1.0x, Tier 2 = 1.25x, Tier 3 = 1.5x
	var tier_mult := 1.0
	if drift_tier >= 3:
		tier_mult = 1.5
	elif drift_tier >= 2:
		tier_mult = 1.25

	var boost_power := minf(drift_boost_base + drift_boost_per_second * drift_charge_time, drift_boost_max)
	boost_power *= tier_mult

	var forward_dir := Vector2.from_angle(rotation - PI / 2.0)

	# Slingshot: blend velocity direction toward facing direction
	var current_dir := velocity.normalized() if velocity.length() > 10.0 else forward_dir
	var blended_dir := current_dir.lerp(forward_dir, GameConstants.DRIFT_BOOST_REDIRECT).normalized()
	velocity = blended_dir * (current_speed + boost_power)

	# Post-boost linger — reduced drag for a brief time
	_boost_linger_timer = GameConstants.DRIFT_BOOST_LINGER

	is_boosting = true
	boost_timer = TRAIL_DURATION
	_trail.clear_points()

	drift_released.emit(boost_power)

	# Boost pop animation
	if _boost_tween:
		_boost_tween.kill()
	_boost_tween = create_tween()
	_boost_tween.tween_property(_car_sprite, "scale", Vector2(1.2, 1.2), 0.06)
	_boost_tween.parallel().tween_property(_nose_sprite, "scale", Vector2(1.2, 1.2), 0.06)
	_boost_tween.tween_property(_car_sprite, "scale", Vector2.ONE, 0.2)
	_boost_tween.parallel().tween_property(_nose_sprite, "scale", Vector2.ONE, 0.2)

	drift_state = DriftState.NONE

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
	# AI-only direct fire path — always homing
	print("[Combat] P%d fired missile (remaining: %d)" % [player_id, missile_count - 1])
	missile_count -= 1
	var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
	var side_offset := 10.0 if _missile_side == 0 else -10.0
	_missile_side = 1 - _missile_side
	var right_dir := Vector2.from_angle(rotation)
	var spawn_pos := global_position + forward_dir * 30.0 + right_dir * side_offset
	missile_fired.emit(spawn_pos, forward_dir, self, true)

func hit_by_missile(dir: Vector2) -> void:
	hit_stun_timer = GameConstants.STUN_DURATION
	_hit_spin_speed = GameConstants.STUN_SPIN_SPEED
	velocity *= GameConstants.STUN_VELOCITY_RETAIN
	velocity += dir * GameConstants.STUN_KNOCKBACK
	# Red flash
	_car_sprite.color = Color(1, 0.1, 0.1, 1)
	_nose_sprite.color = Color(1, 0.1, 0.1, 1)
	# Cancel drift
	_cancel_drift()
	# Cancel targeting (missile NOT consumed)
	if targeting_state != TargetingState.IDLE:
		_cancel_targeting()

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

		# Trail color by tier: Grey → Orange → Red → Purple
		var trail_color: Color
		match drift_tier:
			0:
				trail_color = Color(0.3, 0.3, 0.3, 0.6)
			1:
				trail_color = Color(1.0, 0.55, 0.0, 0.7)
			2:
				trail_color = Color(1.0, 0.15, 0.0, 0.8)
			3:
				trail_color = Color(0.7, 0.2, 1.0, 0.9)
			_:
				trail_color = Color(0.3, 0.3, 0.3, 0.6)
		_drift_trail_l.default_color = trail_color
		_drift_trail_r.default_color = trail_color

		# Spark emitters
		if current_speed > drift_min_speed * 0.5:
			_spark_l.position = _spark_l.get_parent().to_local(lw)
			_spark_r.position = _spark_r.get_parent().to_local(rw)
			var spark_mat_l: ParticleProcessMaterial = _spark_l.process_material
			var spark_mat_r: ParticleProcessMaterial = _spark_r.process_material
			spark_mat_l.color = trail_color
			spark_mat_r.color = trail_color
			_spark_l.emitting = true
			_spark_r.emitting = true
		else:
			_spark_l.emitting = false
			_spark_r.emitting = false
	else:
		_spark_l.emitting = false
		_spark_r.emitting = false
		# Fade out drift trails
		if _drift_trail_l.get_point_count() > 0:
			_drift_trail_l.remove_point(0)
		if _drift_trail_r.get_point_count() > 0:
			_drift_trail_r.remove_point(0)

func _update_visuals(delta: float) -> void:
	# Drift charge color by tier
	if is_drift_sliding and drift_charge_ratio > 0.0:
		var charge_color: Color
		if drift_tier <= 1:
			if drift_charge_ratio < 0.5:
				charge_color = color_normal.lerp(color_charge_mid, drift_charge_ratio * 2.0)
			else:
				charge_color = color_charge_mid.lerp(color_charge_full, (drift_charge_ratio - 0.5) * 2.0)
		elif drift_tier == 2:
			charge_color = color_charge_full
		else:
			# Tier 3 — purple with pulse
			charge_color = color_charge_max
		_car_sprite.color = charge_color
		if drift_tier >= 3:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			_nose_sprite.color = color_charge_max.lerp(Color.WHITE, pulse * 0.5)
		elif drift_charge_ratio >= 1.0:
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

	# Slight car body lean during drift
	if is_drift_sliding and abs(steer_input) > 0.1:
		var lean_target := steer_input * drift_charge_ratio * 0.15
		_car_sprite.rotation = lerp(_car_sprite.rotation, lean_target, delta * 8.0)
		_nose_sprite.rotation = _car_sprite.rotation
	else:
		_car_sprite.rotation = lerp(_car_sprite.rotation, 0.0, delta * 10.0)
		_nose_sprite.rotation = _car_sprite.rotation

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

	# Apply drag — reduced during post-boost linger
	if _boost_linger_timer > 0.0:
		_boost_linger_timer -= delta
		velocity *= lerp(drag, 1.0, 0.5)  # Half the drag during linger
	else:
		velocity *= drag

	# Absolute speed cap prevents infinite stacking from drift + item boost
	if velocity.length() > GameConstants.ABSOLUTE_MAX_SPEED:
		velocity = velocity.normalized() * GameConstants.ABSOLUTE_MAX_SPEED

	# Steering
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
	_cancel_drift()
	_end_targeting()
	is_boosting = false
	boost_timer = 0.0
	_boost_linger_timer = 0.0
	item_boost_active = false
	item_boost_timer = 0.0
	hit_stun_timer = 0.0
	missile_count = 0
	has_item = false
	current_traction = base_traction
	_car_sprite.color = color_normal
	_nose_sprite.color = color_nose_normal
	_car_sprite.scale = Vector2.ONE
	_nose_sprite.scale = Vector2.ONE
	_car_sprite.position = Vector2.ZERO
	_nose_sprite.position = Vector2.ZERO
	_car_sprite.rotation = 0.0
	_nose_sprite.rotation = 0.0
	_trail.clear_points()
	_item_trail.clear_points()
	_drift_trail_l.clear_points()
	_drift_trail_r.clear_points()
	_spark_l.emitting = false
	_spark_r.emitting = false
	if _missile_sprite_l:
		_missile_sprite_l.visible = false
	if _missile_sprite_r:
		_missile_sprite_r.visible = false
	if _boost_tween:
		_boost_tween.kill()

func start_race() -> void:
	race_started = true
	wall_hit_count = 0

func stop_race() -> void:
	race_started = false
	if targeting_state != TargetingState.IDLE:
		_cancel_targeting()

func set_target_car(target: CharacterBody2D) -> void:
	_target_car = target

# -- Missile Sprites --

func _create_missile_sprites() -> void:
	# Half-size missile shapes at headlight positions
	var shape := PackedVector2Array([
		Vector2(0, -8), Vector2(3, -2),
		Vector2(2.5, 5), Vector2(-2.5, 5),
		Vector2(-3, -2)
	])
	_missile_sprite_l = Polygon2D.new()
	_missile_sprite_l.polygon = shape
	_missile_sprite_l.color = Color(1.0, 0.3, 0.05, 0.9)
	_missile_sprite_l.visible = false
	add_child(_missile_sprite_l)

	_missile_sprite_r = Polygon2D.new()
	_missile_sprite_r.polygon = shape
	_missile_sprite_r.color = Color(1.0, 0.3, 0.05, 0.9)
	_missile_sprite_r.visible = false
	add_child(_missile_sprite_r)

func _update_missile_sprites(delta: float) -> void:
	_missile_bob_time += delta
	var bob := sin(_missile_bob_time * GameConstants.MISSILE_BOB_FREQUENCY * TAU) * GameConstants.MISSILE_BOB_AMPLITUDE

	# Determine visibility based on missile count and which side fires next
	var show_l := false
	var show_r := false
	if missile_count >= 2:
		show_l = true
		show_r = true
	elif missile_count == 1:
		# Show the sprite on the side that will fire next
		if _missile_side == 0:
			show_l = true
		else:
			show_r = true

	# Hide the sprite being aimed during targeting
	if targeting_state != TargetingState.IDLE:
		if _missile_side == 0:
			show_l = false
		else:
			show_r = false

	_missile_sprite_l.visible = show_l
	_missile_sprite_r.visible = show_r
	_missile_sprite_l.position = Vector2(-10, -30 + bob)
	_missile_sprite_r.position = Vector2(10, -30 + bob)

# -- Targeting System --

func _create_reticle() -> void:
	_reticle_node = Node2D.new()
	_reticle_node.top_level = true
	_reticle_node.z_index = 5
	_reticle_node.visible = false

	# Outer ring
	_reticle_ring = Polygon2D.new()
	_reticle_ring.polygon = GameConstants.make_circle(GameConstants.RETICLE_RADIUS, 24)
	_reticle_ring.color = Color(1, 0.2, 0.1, 0.0)  # Transparent fill
	_reticle_node.add_child(_reticle_ring)

	# Ring outline via Line2D
	var ring_line := Line2D.new()
	var ring_pts := GameConstants.make_circle(GameConstants.RETICLE_RADIUS, 24)
	ring_pts.append(ring_pts[0])  # Close the loop
	ring_line.points = ring_pts
	ring_line.width = 2.0
	ring_line.default_color = Color(1, 0.2, 0.1, 0.9)
	ring_line.name = "RingLine"
	_reticle_node.add_child(ring_line)

	# Inner dot
	_reticle_dot = Polygon2D.new()
	_reticle_dot.polygon = GameConstants.make_circle(3.0, 8)
	_reticle_dot.color = Color(1, 0.3, 0.1, 0.9)
	_reticle_node.add_child(_reticle_dot)

	add_child(_reticle_node)

func _begin_targeting() -> void:
	targeting_state = TargetingState.SEEKING
	_targeting_timer = 0.0
	_reticle_locked = false
	_reticle_spin = 0.0
	# Spawn reticle 80 units ahead of car
	var forward := Vector2.from_angle(rotation - PI / 2.0)
	_reticle_pos = global_position + forward * 80.0
	_reticle_node.global_position = _reticle_pos
	_reticle_node.visible = true
	# Set red seeking color
	_set_reticle_color(Color(1, 0.2, 0.1, 0.9))

func _update_targeting(delta: float) -> void:
	_targeting_timer += delta
	_reticle_spin += delta * 2.0

	# Timeout — cancel without consuming missile
	if _targeting_timer >= GameConstants.RETICLE_TIMEOUT:
		_cancel_targeting()
		return

	# Find forward target
	var has_target := _find_forward_target()

	if targeting_state == TargetingState.SEEKING:
		if has_target and _target_car and is_instance_valid(_target_car):
			# Move reticle toward target
			var target_pos := _target_car.global_position
			var to_target := target_pos - _reticle_pos
			var dist := to_target.length()
			if dist < GameConstants.RETICLE_LOCK_DISTANCE:
				# Lock on!
				targeting_state = TargetingState.LOCKED
				_reticle_locked = true
				_set_reticle_color(Color(0.1, 1.0, 0.2, 0.9))
			else:
				_reticle_pos += to_target.normalized() * GameConstants.RETICLE_SEEK_SPEED * delta
		else:
			# No target — drift forward slowly
			var forward := Vector2.from_angle(rotation - PI / 2.0)
			_reticle_pos += forward * 200.0 * delta
			# Dim red when no target
			_set_reticle_color(Color(1, 0.2, 0.1, 0.4))

	elif targeting_state == TargetingState.LOCKED:
		if _target_car and is_instance_valid(_target_car):
			_reticle_pos = _target_car.global_position
			# Gentle pulse animation
			var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.01)
			_reticle_node.scale = Vector2(pulse, pulse)
		else:
			# Target lost — revert to seeking
			targeting_state = TargetingState.SEEKING
			_reticle_locked = false
			_reticle_node.scale = Vector2.ONE
			_set_reticle_color(Color(1, 0.2, 0.1, 0.9))

	_reticle_node.global_position = _reticle_pos
	_reticle_node.rotation = _reticle_spin

func _find_forward_target() -> bool:
	if not _target_car or not is_instance_valid(_target_car):
		return false
	var to_target := _target_car.global_position - global_position
	var dist := to_target.length()
	if dist > GameConstants.RETICLE_SEARCH_RANGE:
		return false
	var forward := Vector2.from_angle(rotation - PI / 2.0)
	var angle := forward.angle_to(to_target.normalized())
	return absf(angle) <= GameConstants.RETICLE_FORWARD_CONE

func _cancel_targeting() -> void:
	# Cancel without consuming missile
	_end_targeting()

func _end_targeting() -> void:
	targeting_state = TargetingState.IDLE
	_targeting_timer = 0.0
	_reticle_locked = false
	if _reticle_node:
		_reticle_node.visible = false
		_reticle_node.scale = Vector2.ONE
		_reticle_node.rotation = 0.0

func _fire_missile_targeted() -> void:
	print("[Combat] P%d fired targeted missile (locked: %s, remaining: %d)" % [player_id, str(_reticle_locked), missile_count - 1])
	missile_count -= 1
	var forward_dir := Vector2.from_angle(rotation - PI / 2.0)
	var side_offset := 10.0 if _missile_side == 0 else -10.0
	_missile_side = 1 - _missile_side
	var right_dir := Vector2.from_angle(rotation)
	var spawn_pos := global_position + forward_dir * 30.0 + right_dir * side_offset
	# Direction toward reticle position
	var dir := (_reticle_pos - spawn_pos).normalized()
	if dir.length() < 0.1:
		dir = forward_dir
	missile_fired.emit(spawn_pos, dir, self, _reticle_locked)
	_end_targeting()

func _set_reticle_color(col: Color) -> void:
	if _reticle_dot:
		_reticle_dot.color = col
	var ring_line: Line2D = _reticle_node.get_node_or_null("RingLine")
	if ring_line:
		ring_line.default_color = col
