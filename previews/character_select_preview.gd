extends Node3D
## F6 layout preview for the character select screen. Mirrors the real desktop
## camera (arena/arena_backdrop.tscn). Run with `-- --shot=<path>` to save a
## screenshot and quit, which is how the layout gets checked without the editor.

const SELECT_SCENE := preload("res://ui/character_select.tscn")

func _ready() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 2.0480173)
	camera.current = true
	add_child(camera)
	var select := SELECT_SCENE.instantiate() as CharacterSelect
	add_child(select)
	SceneManager.state = SceneManager.FlowState.SELECTING
	select.open.call_deferred()
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	if shot.is_empty():
		return
	for i in 45:
		await get_tree().process_frame
	select._cursor[1] = 5
	select._refresh_stage(1)
	select._lock_player(0)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()
