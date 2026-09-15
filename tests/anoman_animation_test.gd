extends Node
@export var character_id: StringName = &"anoman"

func _ready() -> void:
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	var expected_damage := [7, 10, 12, 17, 12] if character_id == &"dasamuka" else [5, 6, 8, 11, 8]
	var keys := ["neutral", "up", "down", "melee_special", "ranged_special"]
	for side in [1, 2]:
		var fighter := load("res://fighter/fighter_%d.tscn" % side).instantiate() as Fighter
		fighter.input_left = "p1_left"
		fighter.input_right = "p1_right"
		fighter.input_up = "p1_up"
		fighter.input_down = "p1_down"
		add_child(fighter)
		fighter.set_physics_process(false)
		fighter.facing = 1.0 if side == 1 else -1.0
		fighter.configure_character(character_id)
		var animator = fighter._move_animator(fighter.character_definition["moves"]["neutral"])
		for i in keys.size():
			var move: Dictionary = fighter.character_definition["moves"][keys[i]]
			assert(move["damage"] == expected_damage[i], "Damage changed")
			fighter._start_attack(move)
			assert(not fighter.hitbox.is_attacking, "Startup must not deal damage")
			await get_tree().create_timer(float(move["startup"]) + 0.025).timeout
			assert(fighter.hitbox.is_attacking, "Active window missing")
			assert(fighter.skeleton_animation_player.current_animation.begins_with(String(character_id) + "/"))
			await get_tree().create_timer(float(move["active"]) + float(move["recovery"]) + 0.08).timeout
			assert(not fighter.hitbox.is_attacking)
			assert(fighter.combat_state == Fighter.CombatState.READY)
			for j in animator.joints.size():
				assert(is_equal_approx(animator.joints[j].rotation, animator.rest[j]), "Joint did not recover")
			# Sample the actual hand shape against a standing opponent at the
			# arena's 1060px separation over a usable forward lean range,
			# including the live puppet's rotation around its stick pivot.
			animator.play(move)
			var target := RectangleShape2D.new()
			target.size = Vector2(159, 488)
			var target_offset := Vector2(10.0, 120.0) if side == 1 else Vector2(4.7892504, 68.48947)
			var target_transform := Transform2D(0, Vector2(1060 * fighter.facing, 0) + target_offset)
			var reachable := false
			fighter.hitbox._shape.scale = fighter.hitbox._base_shape_scale * float(move["reach_scale"])
			for lean_step in 6:
				var lean := 0.5 + lean_step * 0.1
				var rotation := deg_to_rad(fighter.max_lean_angle_deg) * fighter.facing * lean
				fighter.puppet_visual.rotation = rotation
				fighter.puppet_visual.position = fighter.lean_pivot - fighter.lean_pivot.rotated(rotation) + Vector2((fighter.max_lean_distance * lean + float(move["lunge"])) * fighter.facing, float(move["drop"]))
				for sample in 11:
					fighter.skeleton_animation_player.seek(float(move["startup"]) + float(move["active"]) * sample / 10.0, true)
					reachable = reachable or _hand_overlaps(fighter.hitbox._shape, target, target_transform)
			if not reachable:
				print("REACH ", side, " ", keys[i], " hand=", fighter.hitbox._shape.global_transform, " radius=", fighter.hitbox._shape.shape.radius, " target=", target_transform)
			assert(reachable, "Move cannot reach standing target: side %d %s" % [side, keys[i]])
			fighter.reset()
			fighter.puppet_visual.position = Vector2.ZERO
			fighter.puppet_visual.rotation = 0.0
		# Cancel startup and verify old timers cannot reactivate the hand.
		fighter._start_attack(fighter.character_definition["moves"]["melee_special"])
		await get_tree().create_timer(0.05).timeout
		fighter._interrupt_attack()
		await get_tree().create_timer(0.3).timeout
		assert(not fighter.hitbox.is_attacking)
		assert(fighter._attack_offset.is_zero_approx())
		fighter.reset()
		# Reset during an active attack also invalidates the old coroutine.
		fighter._start_attack(fighter.character_definition["moves"]["up"])
		await get_tree().create_timer(float(fighter.character_definition["moves"]["up"]["startup"]) + 0.025).timeout
		fighter.reset()
		await get_tree().create_timer(0.8).timeout
		assert(fighter.combat_state == Fighter.CombatState.READY)
		assert(not fighter.hitbox.is_attacking)
		fighter.configure_character(&"bima")
		assert(fighter.max_lean_distance == (550.0 if side == 1 else 780.0))
		assert(not fighter.character_definition["moves"]["neutral"].has("presentation"))
		fighter._start_attack(fighter.character_definition["moves"]["neutral"])
		await get_tree().create_timer(0.16).timeout
		assert(fighter.skeleton_animation_player.current_animation == "attack")
		await get_tree().create_timer(1.0).timeout
		fighter.queue_free()
		await get_tree().process_frame
	print("PASS: ", character_id, " five moves on both rigs; damage, reach, phases, recovery, interrupt, reset and other-character isolation")
	get_tree().quit()

func _hand_overlaps(shape: CollisionShape2D, target: RectangleShape2D, target_transform: Transform2D) -> bool:
	# Shape2D.collide uses shape dimensions; bake the hand node scale into
	# the circle just as the physics body does when creating its shape.
	var circle := CircleShape2D.new()
	circle.radius = shape.shape.radius * shape.global_scale.x
	return circle.collide(Transform2D(0.0, shape.global_position), target, target_transform)
