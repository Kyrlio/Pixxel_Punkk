class_name GroundEnemy
extends Enemy


@onready var wall_detection_raycast: RayCast2D = %WallDetectionRaycast
@onready var visuals: Node2D = $Visuals
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_animation_player: AnimationPlayer = $HitFlashAnimationPlayer
@onready var ledge_detection_raycast: RayCast2D = %LedgeDetectionRaycast



var direction: float = 1.0
var is_dead: bool = false
var can_move: bool = true


func _process(delta: float) -> void:
	if is_dead or not can_move:
		return
	
	_movement(delta)
	_update_direction()
	
	move_and_slide()


func _movement(delta) -> void:
	velocity.x = speed * direction
	velocity.y = GRAVITY * delta


func _update_direction() -> void:
	if not wall_detection_raycast.is_colliding() and ledge_detection_raycast.is_colliding():
		return
	
	direction *= -1.0
	visuals.scale = Vector2(direction, 1)


func _on_damaged() -> void:
	hit_flash_animation_player.play("hit")


func _on_died() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	animation_player.play("death")


func _can_move(value: bool) -> void:
	can_move = value
