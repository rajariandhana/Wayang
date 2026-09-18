extends Node2D
## Renders Sura/Baya skins on both rigs, at rest and mid-attack, to PNGs.
## Run windowed: Godot --path . res://tests/skin_preview.tscn -- <out_dir>

var out_dir := "user://"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	get_window().size = Vector2i(2400, 1300)
	RenderingServer.set_default_clear_color(Color(0.45, 0.45, 0.45))
	_run.call_deferred()

func _spawn(side: int, id: StringName, x: float) -> Fighter:
	var f := load("res://fighter/fighter_%d.tscn" % side).instantiate() as Fighter
	f.position = Vector2(x, 650)
	f.scale = Vector2(0.55, 0.55)
	add_child(f)
	f.set_physics_process(false)
	f.configure_character(id)
	return f

func _run() -> void:
	var fighters: Array[Fighter] = [
		_spawn(1, &"sura", 300), _spawn(2, &"baya", 900),
		_spawn(1, &"baya", 1500), _spawn(2, &"sura", 2100)]
	await _frames(4)
	await _shot("rest")
	for key in ["neutral", "up", "down", "melee_special", "ranged_special"]:
		for f in fighters:
			var move: Dictionary = f.character_definition["moves"][key]
			f._move_animator(move).play(move)
			f.skeleton_animation_player.seek(float(move["startup"]) + float(move["active"]) * 0.5, true)
		await _frames(3)
		await _shot(key)
	# Switching back to a plain character must restore the original rig.
	for f in fighters:
		f.configure_character(&"anoman" if f.name.begins_with("Fighter1") else &"dasamuka")
	await _frames(4)
	await _shot("restored")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
