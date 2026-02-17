extends Area2D

@export var checkpoint_index: int = 0
@export var is_finish_line: bool = false

signal checkpoint_triggered(index: int)
signal finish_line_crossed

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		if is_finish_line:
			finish_line_crossed.emit()
		else:
			checkpoint_triggered.emit(checkpoint_index)
