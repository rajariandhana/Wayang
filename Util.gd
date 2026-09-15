extends Node

func wait(seconds: float) -> void:
	# Combat waits inherit SceneTree.paused. SceneTreeTimer defaults to always
	# processing, which allowed startup/active/recovery windows to elapse behind
	# the pause overlay.
	await get_tree().create_timer(seconds, false).timeout
