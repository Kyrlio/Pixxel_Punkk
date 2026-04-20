class_name SpikyEnemy
extends Enemy

const STICK_FORCE: float = 80.0
const TURN_ANGLE: float = PI * 0.5
const TURN_COOLDOWN: float = 0.08

@onready var wall_detection_raycast: RayCast2D = %WallDetectionRaycast
@onready var visuals: Node2D = $Visuals
@onready var ground_detection_raycast: RayCast2D = %GroundDetectionRaycast
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_animation_player: AnimationPlayer = $HitFlashAnimationPlayer


var direction: float = 1.0
var is_dead: bool = false
var can_move: bool = true
var turn_cooldown_left: float = 0.0


func _physics_process(delta: float) -> void:
	if is_dead or not can_move:
		return

	turn_cooldown_left = max(turn_cooldown_left - delta, 0.0)
	_update_visual_direction()
	_move_on_surface()
	_try_turn()

	move_and_slide()


func _move_on_surface() -> void:
	var forward := transform.x.normalized() * direction
	var down := transform.y.normalized()
	velocity = forward * speed + down * STICK_FORCE


func _try_turn() -> void:
	if turn_cooldown_left > 0.0:
		return

	ground_detection_raycast.force_raycast_update()
	wall_detection_raycast.force_raycast_update()

	if not ground_detection_raycast.is_colliding():
		_rotate_by(direction * TURN_ANGLE)
		return

	if wall_detection_raycast.is_colliding():
		_rotate_by(-direction * TURN_ANGLE)


func _rotate_by(angle: float) -> void:
	rotation += angle
	turn_cooldown_left = TURN_COOLDOWN


func _update_visual_direction() -> void:
	visuals.scale = Vector2(direction, 1)


func _on_damaged() -> void:
	hit_flash_animation_player.play("hit")


func _on_died() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	animation_player.play("death")


func _can_move(value: bool) -> void:
	can_move = value
