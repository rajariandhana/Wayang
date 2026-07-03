extends Node

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
