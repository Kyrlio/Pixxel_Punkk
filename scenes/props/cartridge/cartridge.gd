class_name Cartridge
extends RigidBody2D

@onready var life_timer: Timer = $LifeTimer

@export var speed_min: float = 90.0
@export var speed_max: float = 150.0


func _ready() -> void:
	gravity_scale = 1.0
	linear_damp = 1.5
	angular_damp = 0.5


func start(aim_vector: Vector2) -> void:
	var side := -aim_vector.normalized()
	var eject_dir := Vector2(side.x, -1.0).normalized()
	
	linear_velocity = eject_dir * randf_range(speed_min, speed_max)
	angular_velocity = randf_range(-18.0, 18.0)


func _on_life_timer_timeout() -> void:
	queue_free.call_deferred()
