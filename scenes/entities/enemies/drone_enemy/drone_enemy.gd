class_name DroneEnemy
extends Enemy

enum STATE {
	PATROL,
	CHASE,
	INVESTIGATE,
	ATTACK,
	DEATH
}

const VISION_THRESHOLD: float = 0.5
const PATROL_RADIUS: float = 100.0

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_animation: AnimationPlayer = $HitFlashAnimation
@onready var see_raycast: RayCast2D = $SeeRayCast

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

func setup(_grid: AStarGrid2D):
	grid = _grid
	current_cell = pos_to_cell(global_position)
	target_cell = current_cell


func _ready() -> void:
	super._ready()
	patrol_center = global_position


func _physics_process(delta: float) -> void:
	$Label.text = get_string_current_state()
	update_visuals_facing()
	process_state(delta)


func switch_state(to_state: STATE) -> void:
	var _previous_state: STATE = active_state
	active_state = to_state
	
	match active_state:
		STATE.PATROL:
			print("PATTROL")
			animation_player.play("default")
		
		STATE.CHASE:
			print("CHASE")
			animation_player.play("default")
			
		STATE.INVESTIGATE:
			print("INVESTIGATE")
			animation_player.play("default")
		
		STATE.ATTACK:
			print("attack")
			animation_player.play("attack")
		
		STATE.DEATH:
			print("die")
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
			
			var target = Vector2i(pos_to_cell(player.position))
			if target != target_cell:
				var new_path = grid.get_point_path(current_cell, target)
				if new_path:
					move_pts = new_path
					move_pts = (move_pts as Array).map(func (p): return p + grid.cell_size / 2.0)
					if $PathPreviz:
						$PathPreviz.points = move_pts
					target_cell = target
					start_move()
			
			process_movement(delta)
			
		STATE.INVESTIGATE:
			if check_player_visibility():
				switch_state(STATE.CHASE)
				return
				
			var is_moving = process_movement(delta)
			if not is_moving:
				patrol_center = global_position
				switch_state(STATE.PATROL)
		
		STATE.ATTACK:
			velocity = Vector2.ZERO
			move_and_slide()
		
		STATE.DEATH:
			velocity = Vector2.ZERO
			move_and_slide()


func process_movement(delta: float) -> bool:
	if moving and move_pts.size() > 0:
		if cur_pt >= move_pts.size() - 1:
			velocity = Vector2.ZERO
			global_position = move_pts[-1]
			current_cell = pos_to_cell(global_position)
			if $PathPreviz:
				$PathPreviz.points = []
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


func generate_random_patrol_path() -> void:
	if not grid:
		return
		
	var random_offset = Vector2(randf_range(-PATROL_RADIUS, PATROL_RADIUS), randf_range(-PATROL_RADIUS, PATROL_RADIUS))
	var target_pos = patrol_center + random_offset
	var target = pos_to_cell(target_pos)
	
	if grid.region.has_point(target) and target != current_cell:
		var new_path = grid.get_point_path(current_cell, target)
		if new_path and new_path.size() > 0:
			move_pts = new_path
			move_pts = (move_pts as Array).map(func (p): return p + grid.cell_size / 2.0)
			if $PathPreviz:
				$PathPreviz.points = move_pts
			target_cell = target
			start_move()


func start_move() -> void:
	if move_pts.is_empty():
		return
	
	cur_pt = 0
	moving = true


func pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / grid.cell_size.x), floor(pos.y / grid.cell_size.y))


func is_player_in_detection_area() -> bool:
	return player_in_detection_area


func check_player_visibility() -> bool:
	var player_direction: Vector2 = player.global_position - global_position
	
	return raycast_on_player()
	
	#var dot_product = direction.dot(player_direction)
	#if dot_product > VISION_THRESHOLD:
		#if raycast_on_player():
			#return true
	#return false


func raycast_on_player() -> bool:
	see_raycast.target_position = (player.global_position - Vector2(0, 5)) - see_raycast.global_position
	if see_raycast.is_colliding() and see_raycast.get_collider() is Player:
		return true
	return false


func update_visuals_facing() -> void:
	visuals.scale = Vector2.ONE if velocity.normalized().x >= 0 else Vector2(-1, 1)


func get_string_current_state() -> String:
	match active_state:
		STATE.PATROL:
			return "PATROL"
		
		STATE.CHASE:
			return "CHASE"
			
		STATE.INVESTIGATE:
			return "INVESTIGATE"
		
		STATE.ATTACK:
			return "ATTACK"
		
		STATE.DEATH:
			return "DEATH"
		
		_: return "NOTHING"


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
