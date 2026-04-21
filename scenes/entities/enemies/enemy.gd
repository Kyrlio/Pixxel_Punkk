class_name Enemy
extends CharacterBody2D

const GRAVITY: float = 500.0

@export var health_component: HealthComponent
@export var hurtbox_component: HurtboxComponent
@export var hitbox_component: HitboxComponent
@export var speed: float = 20.0
@export var health: int = 10
@export var knockback_force: float = 50.0
@export var knockback_upward_force: float = -25.0
@export var knockback_duration: float = 0.05

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_time_left: float = 0.0
var is_dead: bool = false
var can_move: bool = true


func _ready() -> void:
	if health_component:
		health_component.set_max_health(health, true)
		health_component.died.connect(_on_died)
		health_component.damaged.connect(_on_damaged)
	
	if hurtbox_component:
		hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)


func process_knockback(delta: float) -> bool:
	if knockback_time_left > 0.0:
		knockback_velocity.y += GRAVITY * delta
		velocity = knockback_velocity
		move_and_slide()
		
		knockback_time_left = max(0.0, knockback_time_left - delta)
		if knockback_time_left <= 0.0:
			velocity = Vector2.ZERO
			knockback_velocity = Vector2.ZERO
		
		return true
	return false


func _on_hit_by_hitbox(source_hitbox: HitboxComponent) -> void:
	var knockback_dir := signf(global_position.x - source_hitbox.global_position.x)
	if knockback_dir == 0.0:
		knockback_dir = 1.0
	
	knockback_velocity.x = knockback_force * knockback_dir
	knockback_velocity.y = knockback_upward_force
	knockback_time_left = knockback_duration


func _on_damaged() -> void:
	print("Damaged !")


func _on_died() -> void:
	is_dead = true
	can_move = false
	velocity = Vector2.ZERO
