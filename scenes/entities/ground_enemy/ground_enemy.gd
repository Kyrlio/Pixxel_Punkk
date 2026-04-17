class_name GroundEnemy
extends CharacterBody2D

const GRAVITY: float = 500.0

@onready var health_component: HealthComponent = %HealthComponent
@onready var wall_detection_raycast: RayCast2D = %WallDetectionRaycast
@onready var visuals: Node2D = $Visuals
@onready var ledge_detection_raycast: RayCast2D = %LedgeDetectionRaycast
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var speed: float = 20.0

var direction: float = 1.0

func _ready() -> void:
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	_movement(delta)
	_update_direction()
	
	move_and_slide()


func _movement(delta) -> void:
	velocity.x = speed * direction
	velocity.y += GRAVITY * delta


func _update_direction() -> void:
	if not wall_detection_raycast.is_colliding() and ledge_detection_raycast.is_colliding():
		return
	
	direction *= -1.0
	visuals.scale = Vector2(direction, 1)


func _on_damaged() -> void:
	pass


func _on_died() -> void:
	velocity = Vector2.ZERO
	animation_player.play("death")
