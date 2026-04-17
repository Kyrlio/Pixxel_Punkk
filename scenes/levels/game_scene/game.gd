class_name Game
extends Node2D

@export var freeze_slow := 0.06
@export var freeze_time := 0.15

@onready var level_container: Node2D = $LevelContainer

var player: Player


func _ready() -> void:
	player = level_container.find_child("Player", true, false)
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	GameEvents.engine_freeze_requested.connect(freeze_engine)


func freeze_engine() -> void:
	Engine.time_scale = freeze_slow
	await get_tree().create_timer(freeze_time * freeze_slow).timeout
	Engine.time_scale = 1.0
