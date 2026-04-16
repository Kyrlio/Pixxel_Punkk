class_name Gun extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _process(delta: float) -> void:
	look_at(get_global_mouse_position())
