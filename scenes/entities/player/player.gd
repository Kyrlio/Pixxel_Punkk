class_name Player extends CharacterBody2D

enum STATE {
	FALL,
	FLOOR,
	JUMP,
	DOUBLE_JUMP,
	WALL_SLIDE,
	WALL_JUMP,
	ROLL,
	HARD_LANDING,
	DEAD,
	KNOCKBACK,
	SLIDING
}

const MUZZLE_FLASH_SCENE = preload("uid://we7xx2omqegd")
const BULLET_SCENE = preload("uid://c2h20l1u8lgb6")
const CARTRIDGE_SCENE = preload("uid://dxwvjms21i32")
const JUMP_PARTICLES_SCENE = preload("uid://c484p6dfsmn1v")

const RUN_VELOCITY := 100.0
const GROUND_ACCELERATION := 1000.0
const GROUND_FRICTION := 1500.0

const FALL_GRAVITY := 1200.0
const FALL_VELOCITY := 600.0
const JUMP_VELOCITY := -225.0
const DOUBLE_JUMP_VELOCITY := -250.0
const JUMP_HOLD_GRAVITY := 900.0
const JUMP_CUT_GRAVITY := 1900.0
const AIR_ACCELERATION := 900.0
const AIR_FRICTION := 300.0

const LANDING_SQUISH_DURATION := 0.08
const LANDING_SQUISH_RECOVER_DURATION := 0.11
const LANDING_SPRITE_SQUISH := Vector2(1.3, 0.7)
const LANDING_WEAPON_SQUISH := Vector2(1.15, 0.85)

const FIRING_SQUISH_DURATION := 0.05
const FIRING_SQUISH_RECOVER_DURATION := 0.15
const FIRING_SPRITE_SQUISH := Vector2(1.2, 0.8)

const RECOIL_FORCE := 70.0
const RECOIL_AIR_MULT := 1.0
const RECOIL_GROUND_MULT := 0.75
const RECOIL_MAX_X := 260.0
const RECOIL_MAX_Y := 350.0

const WALL_SLIDE_GRAVITY := 150.0
const WALL_SLIDE_VELOCITY := 200.0
const WALL_JUMP_LENGTH := 8.0
const WALL_JUMP_VELOCITY := -250.0

const ROLL_LENGTH := 80.0
const ROLL_VELOCITY := 400.0

const KNOCKBACK_FORCE := 115.0
const KNOCKBACK_UPWARD_FORCE := -150.0
const KNOCKBACK_DURATION := 0.25


@onready var visuals: Node2D = %Visuals
@onready var sprite: Sprite2D = %Sprite2D
@onready var coyote_timer: Timer = %CoyoteTimer
@onready var roll_cooldown: Timer = %RollCooldown
@onready var player_collider: CollisionShape2D = %PlayerCollider
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var weapon_animation_player: AnimationPlayer = $WeaponAnimationPlayer
@onready var weapon_root: Node2D = %WeaponRoot
@onready var weapon_animation_root: Node2D = $Visuals/WeaponRoot/WeaponAnimationRoot
@onready var fire_rate_timer: Timer = %FireRateTimer
@onready var barrel_position: Marker2D = %BarrelPosition
@onready var hard_landing_timer: Timer = %HardLandingTimer
@onready var wall_slide_raycast: RayCast2D = %WallSlideRaycast
@onready var wall_slide_raycast_2: RayCast2D = %WallSlideRaycast2
@onready var health_component: HealthComponent = %HealthComponent
@onready var hurtbox_component: HurtboxComponent = %HurtboxComponent

@export var bullet_damage: int = 1

var active_state: STATE = STATE.FALL
var facing_direction := 1.0
var saved_position: Vector2 = Vector2.ZERO
var hard_landing: bool = false

var can_double_jump: bool = false
var can_roll: bool = false
var can_fire: bool = true
var can_move: bool = true
var wait_for_double_jump_animation_to_finish: bool = false
var is_wall_sliding: bool = false
var knockback_time_left: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

var firing_tween: Tween
var landing_tween: Tween

func _ready() -> void:
	switch_state(active_state)
	animation_player.animation_finished.connect(_on_animation_finished)
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)


func _process(delta: float) -> void:
	update_facing_from_mouse()
	gather_attack_input()
	_process_state(delta)
	move_and_slide()


func switch_state(to_state: STATE) -> void:
	var previous_state := active_state
	active_state = to_state
	
	match active_state:
		STATE.FALL: 			_enter_state_fall(previous_state)
		STATE.FLOOR:			_enter_state_floor(previous_state)
		STATE.JUMP: 			_enter_state_jump(previous_state)
		STATE.DOUBLE_JUMP: 		_enter_state_double_jump(previous_state)
		STATE.ROLL:				_enter_state_roll(previous_state)
		STATE.HARD_LANDING:		_enter_state_hard_landing(previous_state)
		STATE.WALL_SLIDE:		_enter_state_wall_slide(previous_state)
		STATE.WALL_JUMP:		_enter_state_wall_jump(previous_state)
		STATE.DEAD:				_enter_state_dead(previous_state)
		STATE.KNOCKBACK:		_enter_state_knockback(previous_state)


func _process_state(delta: float) -> void:
	match active_state:
		STATE.FALL:										_update_state_fall(delta)
		STATE.FLOOR:									_update_state_floor(delta)
		STATE.JUMP, STATE.DOUBLE_JUMP, STATE.WALL_JUMP: _update_state_jump(delta)
		STATE.WALL_SLIDE: 								_update_state_wall_slide(delta)
		STATE.KNOCKBACK: 								_update_state_knockback(delta)


## Vérifie si le joueur peut glisser le long d'un mur
## Retourne true si :
## - Le joueur est en contact avec un mur uniquement (pas au sol)
## - Le raycast de wall slide détecte une collision
func can_wall_slide() -> bool:
	return is_on_wall_only() and (wall_slide_raycast.is_colliding() or wall_slide_raycast_2.is_colliding())


## Calcule l'offset de positionnement après un ledge climb
## Basé sur les dimensions du collider du joueur
## - X : déplace le joueur à côté du rebord (diamètre * 2.7)
## - Y : remonte le joueur au-dessus du rebord (hauteur / 2)
## Retourne Vector2.ZERO si le collider n'est pas une CircleShape2D
func ledge_climb_offset() -> Vector2:
	var shape := player_collider.shape
	if shape is CircleShape2D:
		var move_player: Vector2 = Vector2(shape.radius * 3.6, -shape.radius * 0.5)
		return move_player
	return Vector2.ZERO


func gather_attack_input() -> void:
	if Input.is_action_pressed("fire"):
		try_fire()


func play_landing_squish() -> void:
	if landing_tween != null and landing_tween.is_running():
		landing_tween.kill()
	
	GameCamera.shake(0.5) 
	
	landing_tween = create_tween()
	landing_tween.set_parallel(true)
	landing_tween.set_trans(Tween.TRANS_QUAD)
	landing_tween.set_ease(Tween.EASE_OUT)
	landing_tween.tween_property(sprite, "scale", LANDING_SPRITE_SQUISH, LANDING_SQUISH_DURATION)
	landing_tween.tween_property(weapon_animation_root, "scale", LANDING_WEAPON_SQUISH, LANDING_SQUISH_DURATION)

	landing_tween.set_parallel(false)
	landing_tween.set_trans(Tween.TRANS_QUAD)
	landing_tween.set_ease(Tween.EASE_OUT)
	landing_tween.tween_property(sprite, "scale", Vector2.ONE, LANDING_SQUISH_RECOVER_DURATION)
	landing_tween.tween_property(weapon_animation_root, "scale", Vector2.ONE, LANDING_SQUISH_RECOVER_DURATION)


func play_hard_landing_squish() -> void:
	if landing_tween != null and landing_tween.is_running():
		landing_tween.kill()
	
	GameCamera.shake(1)
	GameCamera.bump_zoom(Vector2(1.1, 1.1), 0.15, 0.75)
	
	landing_tween = create_tween()
	landing_tween.set_parallel(true)
	landing_tween.set_trans(Tween.TRANS_QUAD)
	landing_tween.set_ease(Tween.EASE_OUT)
	landing_tween.tween_property(sprite, "scale", LANDING_SPRITE_SQUISH - Vector2(0.2, 0.2), LANDING_SQUISH_DURATION)
	landing_tween.tween_property(weapon_animation_root, "scale", LANDING_WEAPON_SQUISH - Vector2(0.2, 0.2), LANDING_SQUISH_DURATION)
	
	landing_tween.set_parallel(false)
	landing_tween.set_trans(Tween.TRANS_QUAD)
	landing_tween.set_ease(Tween.EASE_OUT)
	landing_tween.tween_property(sprite, "scale", Vector2.ONE, LANDING_SQUISH_RECOVER_DURATION + 0.5)
	landing_tween.tween_property(weapon_animation_root, "scale", Vector2.ONE, LANDING_SQUISH_RECOVER_DURATION + 0.5)


func begin_air_jump(jump_velocity: float, consume_double_jump: bool = false) -> void:
	velocity.y = jump_velocity
	coyote_timer.stop()
	if consume_double_jump:
		can_double_jump = false


func apply_jump_gravity(delta: float) -> void:
	var gravity := FALL_GRAVITY
	if velocity.y < 0.0:
		gravity = JUMP_HOLD_GRAVITY if Input.is_action_pressed("jump") else JUMP_CUT_GRAVITY
	velocity.y = minf(velocity.y + gravity * delta, FALL_VELOCITY)


func apply_double_jump_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + FALL_GRAVITY * delta, FALL_VELOCITY)


func try_fire() -> void:
	if not fire_rate_timer.is_stopped() or not can_fire:
		return
	
	var bullet : Bullet = BULLET_SCENE.instantiate()
	bullet.damage = get_bullet_damage()
	#bullet.global_position = weapon_root.global_position
	bullet.global_position = barrel_position.global_position
	bullet.start(get_aim_vector())
	get_parent().add_child(bullet, true)
	
	fire_rate_timer.start()
	
	apply_recoil()
	
	play_fire_effects()


func apply_recoil() -> void:
	var aim := get_aim_vector()
	if aim == Vector2.ZERO:
		return
	
	var recoil_dir := -aim.normalized()
	var mult := RECOIL_GROUND_MULT if is_on_floor() else RECOIL_AIR_MULT
	var impulse := recoil_dir * RECOIL_FORCE * mult
	
	velocity += impulse
	velocity.x = clamp(velocity.x, -RECOIL_MAX_X, RECOIL_MAX_X)
	velocity.y = clamp(velocity.y, -RECOIL_MAX_Y, RECOIL_MAX_Y)


func play_fire_effects() -> void:
	if weapon_animation_player.is_playing():
		weapon_animation_player.stop()
	weapon_animation_player.play("fire")
	
	if firing_tween != null and firing_tween.is_running():
		firing_tween.kill()
	firing_tween = create_tween()
	firing_tween.set_parallel(true)
	firing_tween.set_trans(Tween.TRANS_QUAD)
	firing_tween.set_ease(Tween.EASE_OUT)
	firing_tween.tween_property(sprite, "scale", FIRING_SPRITE_SQUISH, FIRING_SQUISH_DURATION)
	
	firing_tween.set_parallel(false)
	firing_tween.set_trans(Tween.TRANS_QUAD)
	firing_tween.set_ease(Tween.EASE_OUT)
	firing_tween.tween_property(sprite, "scale", Vector2.ONE, FIRING_SQUISH_RECOVER_DURATION)
	firing_tween.tween_property(weapon_animation_root, "scale", Vector2.ONE, FIRING_SQUISH_RECOVER_DURATION)
	
	spawn_muzzle_flash()
	spawn_cartridge()
	GameCamera.shake(0.5)


func spawn_muzzle_flash() -> void:
	var muzzle_flash: Node2D = MUZZLE_FLASH_SCENE.instantiate()
	muzzle_flash.global_position = barrel_position.global_position
	muzzle_flash.rotation = barrel_position.global_rotation
	get_parent().add_child(muzzle_flash)


func spawn_cartridge() -> void:
	var cartridge: Cartridge = CARTRIDGE_SCENE.instantiate()
	cartridge.global_position = barrel_position.global_position
	cartridge.start(get_aim_vector())
	get_parent().add_child(cartridge)


func spawn_jump_particles() -> void:
	var jump_particles: GPUParticles2D = JUMP_PARTICLES_SCENE.instantiate()
	jump_particles.global_position = global_position
	#jump_particles.z_index = 1000
	jump_particles.emitting = true
	get_parent().add_child(jump_particles)
	await jump_particles.finished
	jump_particles.queue_free.call_deferred()


## Gère le déplacement horizontal du joueur avec accélération et friction.
func handle_movement(delta: float, input_direction: float = 0, horizontal_velocity: float = RUN_VELOCITY) -> void:
	if not can_move:
		return
	
	if input_direction == 0:
		input_direction = signf(Input.get_axis("move_left", "move_right"))
	
	var acceleration := AIR_ACCELERATION
	var friction := AIR_FRICTION
	if is_on_floor():
		acceleration = GROUND_ACCELERATION
		friction = GROUND_FRICTION

	var target_velocity_x := input_direction * horizontal_velocity
	if input_direction != 0:
		velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func update_facing_from_mouse() -> void:
	var aim_vector = get_aim_vector()
	var aim_position: Vector2 = weapon_root.global_position + aim_vector
	weapon_root.look_at(aim_position)
	
	# Ne pas retourner le sprite pendant un wall_slide pour éviter de casser l'animation
	# L'arme se tournera quand même avec look_at() sans modifier la scale du joueur
	if not is_wall_sliding:
		visuals.scale = Vector2.ONE if aim_vector.x >= 0 else Vector2(-1, 1)


## Vérifie si le joueur appuie sur la direction vers laquelle il regarde
## Retourne true si la direction d'entrée (gauche/droite) correspond à la direction de face actuelle
func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == facing_direction

## Vérifie si le joueur appuie sur la direction inverse vers laquelle il regarde
## Retourne true si la direction d'entrée (gauche/droite) ne correspond pas à la direction de face actuelle
func is_input_against_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == -facing_direction


func get_aim_vector() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized()


func get_bullet_damage() -> int:
	return bullet_damage


func _on_animation_finished(_anim_name: String) -> void:
	if _anim_name == "double_jump":
		wait_for_double_jump_animation_to_finish = false
		if is_on_floor():
			switch_state(STATE.FLOOR)
		else:
			switch_state(STATE.FALL)


## Déterminer de quel côté du joueur se trouve le mur
## Retourne 1 si le mur est à droite, -1 si le mur est à gauche
func get_wall_direction() -> int:
	# Vérifier les collisions du CharacterBody2D pour déterminer le côté du mur
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		# Une collision murale a une normale horizontale
		if abs(normal.y) < 0.5 and normal.x != 0:
			# normal.x positif = mur à droite, négatif = mur à gauche
			return 1 if normal.x > 0 else -1
	
	# Fallback : utiliser la direction du dernier mouvement
	# ou les raycast pour déterminer le côté
	if wall_slide_raycast.is_colliding() and not wall_slide_raycast_2.is_colliding():
		# Supposer que raycast pointe à droite (à vérifier selon votre scène)
		return -1
	elif wall_slide_raycast_2.is_colliding() and not wall_slide_raycast.is_colliding():
		# Supposer que raycast_2 pointe à gauche
		return 1
	
	# Dernier fallback
	return 1 if velocity.x >= 0 else -1


# --------------------------------- ENTER STATES LOGIC --------------------------------------------

func _enter_state_fall(previous_state: STATE) -> void:
	weapon_root.visible = true
	can_fire = true
	is_wall_sliding = false
	if animation_player.current_animation != "falling":
		animation_player.play("falling")
	if previous_state == STATE.FLOOR:
		coyote_timer.start()


func _enter_state_floor(previous_state: STATE) -> void:
	weapon_root.visible = true
	can_double_jump = true
	can_roll = true
	can_fire = true
	is_wall_sliding = false
	velocity.y = 0
	coyote_timer.stop()
	
	if previous_state == STATE.FALL or previous_state == STATE.DOUBLE_JUMP:
		if hard_landing:
			switch_state(STATE.HARD_LANDING)
		else:
			play_landing_squish()


func _enter_state_jump(_previous_state: STATE) -> void:
	weapon_root.visible = true
	can_fire = true
	is_wall_sliding = false
	animation_player.play("jump")
	begin_air_jump(JUMP_VELOCITY)
	spawn_jump_particles()


func _enter_state_double_jump(_previous_state: STATE) -> void:
	is_wall_sliding = false
	animation_player.play("double_jump")
	wait_for_double_jump_animation_to_finish = true
	begin_air_jump(DOUBLE_JUMP_VELOCITY, true) 


func _enter_state_wall_slide(_previous_state: STATE) -> void:
	is_wall_sliding = true
	can_double_jump = true
	animation_player.play("wall_slide")
	velocity.y = 0
	# Orienter le sprite vers le mur
	var wall_dir = get_wall_direction()
	visuals.scale = Vector2.ONE if wall_dir > 0 else Vector2(-1, 1)


func _enter_state_wall_jump(previous_state: STATE) -> void:
	animation_player.play("jump")
	velocity.y = WALL_JUMP_VELOCITY
	saved_position = position


func _enter_state_roll(previous_state: STATE) -> void:
	is_wall_sliding = false
	if roll_cooldown.time_left > 0:
		active_state = previous_state
		return
	#animation_player.play("roll")
	velocity.y = 0


func _enter_state_hard_landing(_previous_state: STATE) -> void:
	is_wall_sliding = false
	can_move = false
	hard_landing = false
	velocity = Vector2.ZERO
	play_hard_landing_squish()
	animation_player.play("RESET")
	hard_landing_timer.start()


func _enter_state_dead(_previous_state: STATE) -> void:
	GameCamera.shake(1)
	can_move = false
	velocity = Vector2.ZERO
	GameEvents.emit_engine_freeze()
	animation_player.play("death")


func _enter_state_knockback(_previous_state: STATE) -> void:
	can_fire = false
	is_wall_sliding = false
	velocity = knockback_velocity
	animation_player.play("hit")



# --------------------------------------- UPDATE STATE LOGIC --------------------------------------

func _update_state_fall(delta: float) -> void:
	velocity.y = minf(velocity.y + FALL_GRAVITY * delta, FALL_VELOCITY)
	handle_movement(delta)
	
	if velocity.y >= FALL_VELOCITY:
		hard_landing = true
	
	if is_on_floor():
		switch_state(STATE.FLOOR)
	elif Input.is_action_just_pressed("jump"):
		if coyote_timer.time_left > 0:
			switch_state(STATE.JUMP)
		elif can_double_jump:
			switch_state(STATE.DOUBLE_JUMP)
	elif (is_input_toward_facing() or is_input_against_facing()) and can_wall_slide():
		switch_state(STATE.WALL_SLIDE)


func _update_state_floor(delta: float) -> void:
	if Input.get_axis("move_left", "move_right"):
		animation_player.play("run")
	else:
		animation_player.play("idle")
	handle_movement(delta)
	
	if not is_on_floor():
		switch_state(STATE.FALL)
	elif Input.is_action_just_pressed("jump"):
		switch_state(STATE.JUMP)


func _update_state_jump(delta: float) -> void:
	if active_state == STATE.DOUBLE_JUMP:
		apply_double_jump_gravity(delta)
	else:
		apply_jump_gravity(delta)
	
	#velocity.y = move_toward(velocity.y, 0, JUMP_HOLD_GRAVITY * delta)
	
	if active_state == STATE.WALL_JUMP:
		var distance := absf(position.x - saved_position.x)
		if distance >= WALL_JUMP_LENGTH:
			active_state = STATE.JUMP
		else:
			handle_movement(delta, get_wall_direction())
	else:
		handle_movement(delta)
	
	if is_on_floor():
		switch_state(STATE.FLOOR)
	elif velocity.y >= 0 and active_state == STATE.JUMP:
		switch_state(STATE.FALL)
	elif active_state == STATE.JUMP and Input.is_action_just_pressed("jump"):
		switch_state(STATE.DOUBLE_JUMP)


func _update_state_wall_slide(delta: float) -> void:
	velocity.y = minf(velocity.y + WALL_SLIDE_GRAVITY * delta, WALL_SLIDE_VELOCITY)
	#velocity.y = move_toward(velocity.y, WALL_SLIDE_VELOCITY, WALL_SLIDE_GRAVITY * delta)
	handle_movement(delta)
	
	if is_on_floor():
		switch_state(STATE.FLOOR)
	elif not can_wall_slide():
		switch_state(STATE.FALL)
	elif Input.is_action_just_pressed("jump"):
		switch_state(STATE.WALL_JUMP)


func _update_state_knockback(delta: float) -> void:
	velocity.y = minf(velocity.y + FALL_GRAVITY * delta, FALL_VELOCITY)
			
	knockback_time_left -= delta
	if knockback_time_left <= 0.0:
		if is_on_floor():
			switch_state(STATE.FLOOR)
		else:
			switch_state(STATE.FALL)



# ---------------------------------------- _ON METHODS -------------------------------------------

func _on_hard_landing_timer_timeout() -> void:
	can_move = true
	switch_state(STATE.FLOOR)


func _on_hit_by_hitbox(source_hitbox: HitboxComponent) -> void:
	if active_state == STATE.DEAD:
		return
		
	var knockback_dir := signf(global_position.x - source_hitbox.global_position.x)
	if knockback_dir == 0.0:
		knockback_dir = facing_direction
		
	knockback_velocity = Vector2(knockback_dir * KNOCKBACK_FORCE, KNOCKBACK_UPWARD_FORCE)
	knockback_time_left = KNOCKBACK_DURATION
	switch_state(STATE.KNOCKBACK)


func _on_died() -> void:
	switch_state(STATE.DEAD)


func _on_damaged() -> void:
	GameEvents.emit_engine_freeze()
	GameCamera.shake(1)
	GameCamera.bump_zoom()
