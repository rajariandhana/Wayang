extends Node2D
## Run this scene (F6) to compare the five attacks without entering commands.
const KEYS := ["neutral", "up", "down", "melee_special", "ranged_special"]
@export var character_id: StringName = &"anoman"
@export var rig_scene: PackedScene = preload("res://fighter/fighter_1.tscn")
@export var preview_facing := 1.0
@export var subtitle := "Existing puppet art • articulated normals • energetic specials"
var fighters: Array[Fighter] = []
var status_labels: Array[Label] = []
var replay_button: Button
var replaying := false
var show_projectiles := false

func _ready() -> void:
	child_entered_tree.connect(_preview_projectile)
	RenderingServer.set_default_clear_color(Color("e8dcc2"))
	get_viewport().set_content_scale_size(Vector2i(1400, 780))
	_label(String(character_id).to_upper() + " / ATTACK STUDY", Vector2(40, 25), 32)
	_label(subtitle, Vector2(40, 75), 20)
	for i in KEYS.size():
		var fighter := rig_scene.instantiate() as Fighter
		fighter.position = Vector2((105 if preview_facing > 0 else 190) + i * 275, 360)
		fighter.facing = preview_facing
		fighter.scale = Vector2.ONE * 0.25
		fighter.input_left = "p1_left"
		fighter.input_right = "p1_right"
		fighter.input_up = "p1_up"
		fighter.input_down = "p1_down"
		add_child(fighter)
		fighter.configure_character(character_id)
		fighter.set_physics_process(false)
		fighter.attack_indicator.hide()
		# Keep comparison puppets and projectiles from hitting each other.
		fighter.get_node("Node2D/Hurtbox").collision_layer = 0
		fighter.get_node("Node2D/Hurtbox").collision_mask = 0
		fighters.append(fighter)
		var move: Dictionary = fighter.character_definition["moves"][KEYS[i]]
		_label(move["name"], Vector2(35 + i * 275, 575), 23)
		status_labels.append(_label("Ready", Vector2(35 + i * 275, 612), 18))
	replay_button = Button.new()
	replay_button.text = "Replay all five"
	replay_button.position = Vector2(40, 685)
	replay_button.pressed.connect(_replay)
	add_child(replay_button)
	var slow := CheckButton.new()
	slow.text = "Slow motion (25%)"
	slow.add_theme_color_override("font_color", Color("302b28"))
	slow.position = Vector2(230, 685)
	slow.toggled.connect(func(enabled: bool): Engine.time_scale = 0.25 if enabled else 1.0)
	add_child(slow)
	var effects := CheckButton.new()
	effects.text = "Show projectiles"
	effects.position = Vector2(510, 685)
	effects.add_theme_color_override("font_color", Color("302b28"))
	effects.toggled.connect(func(enabled: bool):
		show_projectiles = enabled
		for child in get_children():
			if child is Projectile: child.visible = enabled)
	add_child(effects)
	_label("Run this scene with F6. Replay to compare wind-up, contact and recovery.", Vector2(40, 735), 18)
	_replay()
	if ("--capture-" + String(character_id)) in OS.get_cmdline_user_args():
		if character_id == &"dasamuka":
			await get_tree().create_timer(0.14).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/dasamuka-windup.png")
		await get_tree().create_timer(0.24 if character_id == &"dasamuka" else 0.25).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/" + String(character_id) + "-attacks.png")
		if character_id == &"dasamuka":
			await get_tree().create_timer(0.30).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/dasamuka-recovery.png")
		get_tree().quit()

func _preview_projectile(child: Node) -> void:
	if child is Projectile:
		_scale_projectile.call_deferred(child)

func _scale_projectile(projectile: Projectile) -> void:
	if not is_instance_valid(projectile): return
	# Match the miniature puppets; gameplay projectiles are authored at 1:1.
	var fighter := projectile.fighter
	projectile.scale *= 0.25
	projectile.speed *= 0.25
	projectile.max_range *= 0.25
	projectile.global_position = Vector2(
		fighter.puppet_visual.global_position.x + fighter.projectile_spawn_offset.x * fighter.facing * 0.25,
		fighter.global_position.y + fighter.projectile_spawn_offset.y * 0.25)
	projectile.visible = show_projectiles

func _process(delta: float) -> void:
	for i in fighters.size():
		var fighter := fighters[i]
		fighter._update_lean(delta)
		var phase := "Ready"
		if fighter.combat_state == Fighter.CombatState.ATTACK:
			phase = "Contact" if fighter.hitbox.is_attacking else "Wind-up"
		elif fighter.combat_state == Fighter.CombatState.COOLDOWN:
			phase = "Recovery"
		status_labels[i].text = phase

func _replay() -> void:
	if replaying: return
	replaying = true
	replay_button.disabled = true
	var duration := 0.0
	for i in fighters.size():
		var move: Dictionary = fighters[i].character_definition["moves"][KEYS[i]]
		duration = maxf(duration, float(move["startup"]) + float(move["active"]) + float(move["recovery"]))
		fighters[i]._start_attack(fighters[i].character_definition["moves"][KEYS[i]])
	await get_tree().create_timer(duration + 0.15).timeout
	replaying = false
	replay_button.disabled = false

func _label(text: String, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("302b28"))
	add_child(label)
	return label

func _exit_tree() -> void:
	Engine.time_scale = 1.0
