extends CanvasLayer

@onready var cursor_sprite: Sprite2D = %CursorSprite



func _ready() -> void:
	# Afficher le curseur personnalisé au démarrage
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cursor_sprite.visible = true


func _process(_delta: float) -> void:
	cursor_sprite.global_position = cursor_sprite.get_global_mouse_position()


func change_cursor(sprite: CompressedTexture2D, cursor_scale := Vector2.ONE, cursor_pos := Vector2(-10,-8)):
	cursor_sprite.texture = sprite
	cursor_sprite.scale = cursor_scale
	cursor_sprite.offset = cursor_pos


func show_cursor(visibility: bool):
	cursor_sprite.visible = visibility
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func get_actual_cursor() -> CompressedTexture2D:
	return cursor_sprite.texture
