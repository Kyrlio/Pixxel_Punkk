class_name Enemy
extends CharacterBody2D

const GRAVITY: float = 500.0

@export var health_component: HealthComponent
@export var hurtbox_component: HurtboxComponent
@export var hitbox_component: HitboxComponent
@export var speed: float = 20.0
@export var health: int = 10


func _ready() -> void:
	health_component.set_max_health(health, true)
	
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)


func _on_damaged() -> void:
	print("Damaged !")


func _on_died() -> void:
	print("Enemy died !")
