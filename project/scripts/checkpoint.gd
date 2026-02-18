extends Area2D

@export var checkpoint_index: int = 0
@export var is_finish_line: bool = false

signal checkpoint_triggered(index: int, car: CharacterBody2D)
signal finish_line_crossed(car: CharacterBody2D)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		if is_finish_line:
			finish_line_crossed.emit(body)
		else:
			checkpoint_triggered.emit(checkpoint_index, body)
