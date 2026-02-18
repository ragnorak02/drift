extends Camera2D

@export var follow_speed: float = 5.0
@export var lookahead: float = 200.0
@export var zoom_level: float = 0.5

var target: Node2D = null

func _ready() -> void:
	zoom = Vector2(zoom_level, zoom_level)
	enabled = true

func set_target(node: Node2D) -> void:
	target = node

func _process(delta: float) -> void:
	if target:
		var target_pos := target.global_position
		if target is CharacterBody2D and target.velocity.length() > 50.0:
			target_pos += target.velocity.normalized() * lookahead
		global_position = global_position.lerp(target_pos, follow_speed * delta)
