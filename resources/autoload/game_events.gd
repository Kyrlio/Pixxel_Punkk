extends Node

signal engine_freeze_requested

func emit_engine_freeze() -> void:
	engine_freeze_requested.emit()
