extends CanvasLayer

var default_cursor := load("uid://cr1w2deamuhrd")
var pointing_hand_cursor := load("uid://c0mj2iwfce1oy")

func _ready() -> void:
	Input.set_custom_mouse_cursor(default_cursor)


func set_pointing_hand_cursor(toggled: bool) -> void:
	if toggled:
		print("hand")
		Input.set_custom_mouse_cursor(pointing_hand_cursor)
	else:
		print("default")
		Input.set_custom_mouse_cursor(default_cursor)
