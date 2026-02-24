class_name GameConstants

# -- Version --
const VERSION := "0.3.0"
const BUILD_DATE := "2026-02-24"

# -- Car Physics --
const CAR_ACCELERATION := 900.0
const CAR_MAX_SPEED := 1200.0
const CAR_BRAKE_FORCE := 600.0
const CAR_REVERSE_MAX_SPEED := 300.0
const CAR_DRAG := 0.98
const CAR_STEERING_SPEED := 3.0
const CAR_STEERING_CURVE := 0.7
const CAR_MOUSE_STEER_SPEED := 4.0
const CAR_BASE_TRACTION := 0.85
const CAR_TRACTION_TRANSITION_SPEED := 10.0

# -- Drift --
const DRIFT_TRACTION := 0.08
const DRIFT_STEER_MULTIPLIER := 0.5
const DRIFT_MIN_SPEED := 200.0
const DRIFT_SPEED_DECAY := 0.985  # was 0.97 — less aggressive per-frame
const DRIFT_CHARGE_FULL_TIME := 2.5
const DRIFT_BOOST_BASE := 300.0
const DRIFT_BOOST_PER_SECOND := 500.0
const DRIFT_BOOST_MAX := 1400.0
const DRIFT_MIN_ANGLE := 0.15
const DRIFT_MIN_HOLD := 0.2

# -- Drift Tiers --
const DRIFT_TIER_1_TIME := 0.5    # Orange sparks
const DRIFT_TIER_2_TIME := 1.5    # Red sparks
const DRIFT_TIER_3_TIME := 2.5    # Max (purple/white)

# -- Drift Boost Enhancement --
const DRIFT_BOOST_REDIRECT := 0.7  # Blend factor: current velocity dir → facing dir
const DRIFT_BOOST_LINGER := 0.3    # Seconds of reduced drag after boost

# -- Item Boost --
const ITEM_BOOST_SPEED := 500.0
const ITEM_BOOST_DURATION := 2.5
const ITEM_BOOST_MAX_SPEED_MULT := 1.5

# -- Combat / Stun --
const STUN_DURATION := 1.2  # was 1.5 — slightly less punishing
const STUN_SPIN_SPEED := 15.0
const STUN_KNOCKBACK := 250.0  # was 200 — more impactful hit
const STUN_VELOCITY_RETAIN := 0.3
const STUN_SPIN_DECAY := 0.95
const STUN_VELOCITY_DECAY := 0.95

# -- Missile --
const MISSILE_LAUNCH_SPEED := 1800.0
const MISSILE_HOMING_SPEED := 1400.0
const MISSILE_HOMING_TURN_RATE := 2.5
const MISSILE_LAUNCH_DURATION := 1.0
const MISSILE_HOMING_DURATION := 3.0  # was 4.0 — less oppressive tracking
const MISSILE_COLLISION_RADIUS := 12.0
const MISSILE_GRANT_COUNT := 2

# -- Items --
const ITEM_RESPAWN_TIME := 8.0
const MISSILE_RESPAWN_TIME := 10.0
const ITEM_COLLISION_RADIUS := 25.0

# -- Track --
const TRACK_WIDTH := 650.0
const WALL_THICKNESS := 35.0

# -- Combat Test Scenarios (Item 36 — manual verification) --
# 1. Missile fires from alternating left/right headlight positions
# 2. Missile transitions: LAUNCH -> HOMING -> EXPIRED (timeout) correctly
# 3. Missile hits target: stun applied, spin-out plays, velocity knocked back
# 4. (Removed — jump system deleted)
# 5. Stun during drift: drift cancelled, no boost granted
# 6. Stun during item boost: item boost continues through stun (by design)
# 7. Double-stun: second missile during stun resets timer, doesn't stack
# 8. Missile self-hit: missile ignores source car (collision check)
# 9. Missile after race complete: missiles shouldn't fire (race_started=false)
# 10. Speed cap: drift boost + item boost cannot exceed ABSOLUTE_MAX_SPEED

# -- Missile Targeting --
const RETICLE_SEEK_SPEED := 1200.0
const RETICLE_TIMEOUT := 3.5
const RETICLE_LOCK_DISTANCE := 40.0
const RETICLE_FORWARD_CONE := PI / 2.0
const RETICLE_SEARCH_RANGE := 2000.0
const RETICLE_RADIUS := 18.0
const MISSILE_BOB_AMPLITUDE := 2.0
const MISSILE_BOB_FREQUENCY := 3.0

# -- AI Opponent --
const AI_LOOKAHEAD_POINTS := 4
const AI_SHARP_TURN_ANGLE := 0.5
const AI_MISSILE_FIRE_DISTANCE := 800.0
const AI_ITEM_USE_SPEED := 400.0

# -- Speed Cap --
const ABSOLUTE_MAX_SPEED := 2200.0  # prevents infinite speed stacking

# -- Shared Utility --
static func make_circle(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points
