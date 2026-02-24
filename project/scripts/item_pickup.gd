extends Area2D

@export var respawn_time: float = GameConstants.ITEM_RESPAWN_TIME
var _active: bool = true
var _visual: Polygon2D = null
var _glow: Polygon2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Create visual - diamond shape
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(14, 0),
		Vector2(0, 18), Vector2(-14, 0)
	])
	_visual.color = Color(0, 1, 0.5, 0.9)
	add_child(_visual)

	# Glow ring
	_glow = Polygon2D.new()
	_glow.polygon = GameConstants.make_circle(22, 12)
	_glow.color = Color(0, 1, 0.5, 0.2)
	_glow.z_index = -1
	add_child(_glow)

	# Collision shape
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = GameConstants.ITEM_COLLISION_RADIUS
	col.shape = shape
	add_child(col)

func _process(_delta: float) -> void:
	if _active and _visual:
		_visual.rotation += _delta * 2.0
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
		_glow.scale = Vector2(pulse, pulse)

func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body.has_method("collect_item"):
		body.collect_item()
		_active = false
		_visual.visible = false
		_glow.visible = false
		# Respawn after delay
		await get_tree().create_timer(respawn_time).timeout
		_active = true
		_visual.visible = true
		_glow.visible = true

