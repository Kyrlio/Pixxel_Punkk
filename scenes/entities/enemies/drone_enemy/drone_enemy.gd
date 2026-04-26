class_name DroneEnemy
extends Enemy

enum STATE {
	PATROL,
	CHASE,
	INVESTIGATE,
	ATTACK,
	KNOCKBACK,
	DEATH
}

const BULLET_SCENE = preload("uid://dh2i6ev40ltkf")
const MUZZLE_FLASH_SCENE = preload("uid://we7xx2omqegd")

const VISION_THRESHOLD: float = 0.5
const PATROL_RADIUS: float = 100.0
const MELEE_ATTACK_RANGE: float = 20.0
const DISTANCE_ATTACK_RANGE: float = 100.0
const KNOCKBACK_FORCE: float = 200.0
const KNOCKBACK_DURATION: float = 0.15

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_animation: AnimationPlayer = $HitFlashAnimation
@onready var see_raycast: RayCast2D = $SeeRayCast
@onready var flashlight: PointLight2D = $Flashlight
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var alert_sprite: Sprite2D = $AlertSprite
@onready var hitbox_cshape: CollisionShape2D = $HitboxComponent/CollisionShape2D

var active_state: STATE = STATE.PATROL
var player: Player
var player_in_detection_area: bool = false
var can_see_player: bool = false
var player_old_position: Vector2

var grid: AStarGrid2D
var current_cell: Vector2i
var target_cell: Vector2i
var move_pts: Array
var cur_pt: int
var moving: bool = false

var patrol_center: Vector2
var patrol_timer: float = 0.0

var look_direction: Vector2 = Vector2.RIGHT
var base_look_angle: float = 0.0
var look_time: float = 0.0

var alert_tween: Tween

var investigate_sweep_angle: float = 0.0
var investigating_sweeping: bool = false

func setup(_grid: AStarGrid2D):
	grid = _grid
	current_cell = pos_to_cell(global_position)
	target_cell = current_cell


func _ready() -> void:
	super._ready()
	patrol_center = global_position
	alert_sprite.scale = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if process_knockback(delta):
		return
		
	if not can_move:
		return
	
	update_visuals_facing()
	process_state(delta)


func switch_state(to_state: STATE) -> void:
	var previous_state: STATE = active_state
	active_state = to_state
	
	match active_state:
		STATE.PATROL:
			hitbox_cshape.shape.radius = 4
			animation_player.play("default")
		
		STATE.CHASE:
			hitbox_cshape.shape.radius = 4
			animation_player.play("default")
			
			if alert_tween != null and alert_tween.is_valid():
				alert_tween.kill()
			
			if alert_sprite and previous_state == STATE.PATROL:
				alert_tween = create_tween()
				alert_tween.tween_property(alert_sprite, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TransitionType.TRANS_BACK)
				alert_tween.tween_interval(0.2)
				alert_tween.chain().tween_property(alert_sprite, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TransitionType.TRANS_BACK)
			
		STATE.INVESTIGATE:
			animation_player.play("default")
			
			var target = pos_to_cell(player_old_position)
			if target != current_cell and try_navigate_to_cell(target):
				investigating_sweeping = false
			else:
				investigating_sweeping = true
				investigate_sweep_angle = 0.0
		
		STATE.ATTACK:
			attack_cooldown_timer.start()
			var bullet : DroneBullet = BULLET_SCENE.instantiate()
			bullet.global_position = global_position
			bullet.start(get_direction_to_player())
			get_parent().add_child(bullet, true)
			spawn_muzzle_flash()
		
		STATE.KNOCKBACK:
			hit_flash_animation.play("hit")
		
		STATE.DEATH:
			animation_player.play("death")



func process_state(delta: float) -> void:
	match active_state:
		STATE.PATROL:
			if is_player_in_detection_area() and check_player_visibility():
				switch_state(STATE.CHASE)
				return
				
			if not moving:
				velocity = Vector2.ZERO
				move_and_slide()
				
				searching(delta)
				
				patrol_timer -= delta
				if patrol_timer <= 0.0:
					generate_random_patrol_path()
					patrol_timer = randf_range(1.5, 3.5)
			else:
				var _is_moving = process_movement(delta)
		
		STATE.CHASE:
			if not check_player_visibility():
				player_old_position = player.global_position
				switch_state(STATE.INVESTIGATE)
				return
			
			if can_distance_attack_player() and attack_cooldown_timer.is_stopped():
				switch_state(STATE.ATTACK)
			
			var target = pos_to_cell(player.position)
			if target != target_cell:
				try_navigate_to_cell(target)
			
			process_movement(delta)
			
			
		STATE.INVESTIGATE:
			if check_player_visibility():
				switch_state(STATE.CHASE)
				return
				
			if not investigating_sweeping:
				var is_moving = process_movement(delta)
				if not is_moving:
					investigating_sweeping = true
					investigate_sweep_angle = 0.0
			else:
				velocity = Vector2.ZERO
				move_and_slide()
				
				var sweep_speed: float = PI
				investigate_sweep_angle += sweep_speed * delta
				look_direction = Vector2.RIGHT.rotated(base_look_angle - investigate_sweep_angle)
				
				if investigate_sweep_angle >= PI * 2:
					patrol_center = global_position
					switch_state(STATE.PATROL)
		
		STATE.ATTACK:
			velocity = Vector2.ZERO
			move_and_slide()
			switch_state(STATE.CHASE)
			
		STATE.KNOCKBACK:
			velocity = knockback_velocity
			move_and_slide()
			knockback_time_left -= delta
			if knockback_time_left <= 0.0:
				switch_state(STATE.INVESTIGATE)
		
		STATE.DEATH:
			velocity = Vector2.ZERO
			move_and_slide()


func process_movement(delta: float) -> bool:
	if moving and move_pts.size() > 0:
		if cur_pt >= move_pts.size() - 1:
			velocity = Vector2.ZERO
			global_position = move_pts[-1]
			current_cell = pos_to_cell(global_position)
			moving = false
			return false
		else:
			var target_pos = move_pts[cur_pt + 1]
			var dir = (target_pos - global_position).normalized()
			velocity = dir * speed
			move_and_slide()
			if (target_pos - global_position).length() < speed * delta * 2.0 or (target_pos - global_position).length() < 4.0:
				current_cell = pos_to_cell(global_position)
				cur_pt += 1
			return true
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		return false


func spawn_muzzle_flash() -> void:
	var muzzle_flash: Node2D = MUZZLE_FLASH_SCENE.instantiate()
	muzzle_flash.global_position = global_position
	muzzle_flash.rotation = get_direction_to_player().angle()
	get_parent().add_child(muzzle_flash)


func generate_random_patrol_path() -> void:
	if not grid:
		return
		
	var random_offset = Vector2(randf_range(-PATROL_RADIUS, PATROL_RADIUS), randf_range(-PATROL_RADIUS, PATROL_RADIUS))
	var target_pos = patrol_center + random_offset
	var target = pos_to_cell(target_pos)
	
	if grid.region.has_point(target) and target != current_cell:
		try_navigate_to_cell(target)


func try_navigate_to_cell(target: Vector2i) -> bool:
	if not grid:
		return false
		
	var new_path = grid.get_point_path(current_cell, target)
	if new_path and new_path.size() > 0:
		move_pts = new_path
		move_pts = (move_pts as Array).map(func (p): return p + grid.cell_size / 2.0)
		target_cell = target
		start_move()
		return true
		
	return false


func start_move() -> void:
	if move_pts.is_empty():
		return
	
	cur_pt = 0
	moving = true


func pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / grid.cell_size.x), floor(pos.y / grid.cell_size.y))


func is_player_in_detection_area() -> bool:
	return player_in_detection_area


## Return true if the enemy can melee attack the player
## return false otherwise
func can_melee_attack_player() -> bool:
	if not player:
		return false
	
	var distance_to_player = get_distance_to_player()
	return distance_to_player <= MELEE_ATTACK_RANGE


## Return true if the enemy can distance attack the player
## return false otherwise
func can_distance_attack_player() -> bool:
	if not player or can_melee_attack_player():
		return false
	
	var distance_to_player = get_distance_to_player()
	return distance_to_player <= DISTANCE_ATTACK_RANGE


func searching(delta: float) -> void:
	look_time += delta
	
	var sweep_angle = sin(look_time * 3.0) * 1.5
	look_direction = Vector2.RIGHT.rotated(base_look_angle + sweep_angle)


func check_player_visibility() -> bool:
	if not player or not is_player_in_detection_area():
		return false
		
	var player_direction: Vector2 = (player.global_position - global_position).normalized()
	
	var dot_product = look_direction.dot(player_direction)
	if dot_product > VISION_THRESHOLD:
		if raycast_on_player():
			return true
	return false


func raycast_on_player() -> bool:
	see_raycast.target_position = (player.global_position - Vector2(0, 5)) - see_raycast.global_position
	if see_raycast.is_colliding() and see_raycast.get_collider() is Player:
		return true
	return false


func update_visuals_facing() -> void:
	if velocity.length() > 0:
		look_direction = velocity.normalized()
		base_look_angle = look_direction.angle()
		look_time = 0.0
	
	if flashlight:
		flashlight.rotation = lerp_angle(flashlight.rotation, look_direction.angle(), 0.1)
	
	visuals.scale = Vector2.ONE if look_direction.x >= 0 else Vector2(-1, 1)


func _can_move(value: bool) -> void:
	can_move = value


func get_direction_to_player() -> Vector2:
	if not player:
		push_error("get_direction_to_player: no player")
	
	return global_position.direction_to(player.global_position + Vector2(0, -8))


func get_distance_to_player() -> float:
	if not player:
		push_error("get_distance_to_player: no player")
	
	return global_position.distance_to(player.global_position)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body
		player_in_detection_area = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_detection_area = false


func _on_see_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body
		can_see_player = true


func _on_damaged() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		player_old_position = player.global_position
		
		# Calculer la direction de projection (opposée à là où se trouve le joueur)
		var knockback_dir = (global_position - player.global_position).normalized()
		knockback_velocity = knockback_dir * KNOCKBACK_FORCE
		knockback_time_left = KNOCKBACK_DURATION
		
		var target = pos_to_cell(player_old_position)
		if target != current_cell:
			try_navigate_to_cell(target)
	
	switch_state(STATE.KNOCKBACK)


func _on_died() -> void:
	super._on_died()
	animation_player.play("death")
