class_name Bullet
extends Node2D

const SPEED: int = 300

@onready var life_timer: Timer = $LifeTimer
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var direction: Vector2
var source_peer_id: int
var damage: int = 1


func _ready() -> void:
	hitbox_component.damage = damage
	hitbox_component.source_peer_id = source_peer_id
	hitbox_component.hit_hurtbox.connect(_on_hit_hurtbox)
	life_timer.timeout.connect(_on_life_timer_timeout)


func _process(delta: float) -> void:
	global_position += direction * SPEED * delta


func start(dir: Vector2) -> void:
	direction = dir
	rotation = direction.angle()


func register_collision() -> void:
	hitbox_component.is_hit_handled = true
	queue_free()


func spawn_hit_particles() -> void:
	var hit_particles: Node2D = load("uid://dtm267ungrnsi").instantiate()
	hit_particles.global_position = self.global_position
	get_parent().add_child(hit_particles)
	#hit_particles.z_index = 1


func _on_life_timer_timeout() -> void:
	if is_multiplayer_authority():
		queue_free()


func _on_hit_hurtbox(_hurtbox_component: HurtboxComponent) -> void:
	register_collision()


func _on_hitbox_component_body_entered(body: Node2D) -> void:
	if body is TileMapLayer:
		spawn_hit_particles()
		queue_free()
