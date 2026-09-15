extends Node3D

const SELECT_SCENE := preload("res://ui/character_select.tscn")

func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	# character_select.gd fits its quad to get_viewport().get_camera_3d(), so
	# give the test a camera matching the real one (arena/arena_backdrop.tscn).
	var camera := Camera3D.new()
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 2.0480173))
	camera.current = true
	add_child(camera)

	var select := SELECT_SCENE.instantiate() as CharacterSelect
	add_child(select)
	await get_tree().process_frame

	# SceneManager gates all select input behind SELECTING; there is no
	# GameRoot here to put it there, so force it directly.
	SceneManager.state = SceneManager.FlowState.SELECTING

	select.open()
	await get_tree().process_frame
	assert(select.visible, "open() should show the select screen")

	# --- Quad fit -----------------------------------------------------
	var quad: MeshInstance3D = select.get_node(^"DisplayQuad")
	var d: float = camera.global_position.z - select.QUAD_Z
	var tl := camera.project_position(Vector2.ZERO, d)
	var br := camera.project_position(get_viewport().get_visible_rect().size, d)
	var expected_size := Vector2(absf(br.x - tl.x), absf(tl.y - br.y))
	var actual_size: Vector2 = (quad.mesh as QuadMesh).size
	assert(actual_size.distance_to(expected_size) < 0.01, "Quad should fill the camera frustum: got %s expected %s" % [actual_size, expected_size])
	print("PASS: quad fits camera frustum")

	# --- Cursor movement / wrap ----------------------------------------
	assert(select._cursor[0] == 0 and select._cursor[1] == 1, "Cursors should reset on open()")
	await _press(&"p1_right")
	assert(select._cursor[0] == 1, "P1 cursor should move right")
	await _press(&"p1_left")
	await _press(&"p1_left")
	assert(select._cursor[0] == select.GRID_COLS - 1, "P1 cursor should wrap left across the row")
	await _press(&"p1_down")
	assert(select._cursor[0] == select.GRID_COLS - 1 + select.GRID_COLS, "P1 cursor should move to the second row")
	await _press(&"p1_up")
	assert(select._cursor[0] == select.GRID_COLS - 1, "P1 cursor should move back to the first row")
	print("PASS: cursor movement and wrap")

	# --- Lock / unlock ---------------------------------------------------
	select._cursor[0] = 0 # Anoman
	select._cursor[1] = 1 # Dasamuka
	await _press(&"p1_attack")
	assert(select._locked[0], "P1 attack should lock in")
	assert(select._resolved[0] == &"anoman")
	await _press(&"p1_attack")
	assert(not select._locked[0], "P1 attack while locked (P2 still free) should unlock")
	print("PASS: lock/unlock toggling")

	# --- Preview puppet safety -------------------------------------------
	# Grid tiles show a tinted monogram (see character_display.gd) rather than
	# a live puppet each - too many simultaneous skeletal rigs otherwise. Only
	# the two big stage renders use the puppet fallback, so check those.
	await _press(&"p1_attack")
	var stage_display: CharacterDisplay = select._stage_display[0]
	if stage_display._puppet:
		var puppet: Fighter = stage_display._puppet
		assert(puppet.preview_mode, "Stage puppet should be in preview mode")
		assert(not puppet.is_physics_processing(), "Preview puppet should not process physics/input")
		if puppet.hitbox:
			assert(puppet.hitbox.process_mode == Node.PROCESS_MODE_DISABLED, "Preview puppet hitbox should be disabled")
	print("PASS: preview puppets are display-only")

	# --- Both lock -> splash -> signal -----------------------------------
	var received := []
	select.selections_ready.connect(func(p1, p2): received.append([p1, p2]))
	select._cursor[1] = select.RANDOM_INDEX
	await _press(&"p2_attack")
	assert(select._locked[1])
	assert(CharacterRoster.IDS.has(select._resolved[1]), "Random pick should be a real roster id")
	await get_tree().create_timer(2.5).timeout
	assert(received.size() == 1, "selections_ready should fire exactly once")
	assert(received[0][0] == &"anoman")
	print("PASS: both-locked splash emits selections_ready once with resolved ids")

	# --- Countdown auto-lock ----------------------------------------------
	# Reset just the state the countdown test needs, without re-running
	# open()'s full UI/puppet rebuild (redundant here and expensive).
	select._locked = [false, false]
	select._resolved = [&"", &""]
	select._phase = CharacterSelect.Phase.SELECTING
	select._time_left = 0.05
	var received2 := []
	select.selections_ready.connect(func(p1, p2): received2.append([p1, p2]))
	await get_tree().create_timer(3.0).timeout
	assert(select._locked[0] and select._locked[1], "Countdown reaching zero should auto-lock both players")
	assert(received2.size() == 1, "Auto-lock should still emit selections_ready once")
	print("PASS: countdown auto-locks and emits")

	# --- Input gating -------------------------------------------------
	select._locked = [false, false]
	select._resolved = [&"", &""]
	select._phase = CharacterSelect.Phase.SELECTING # only the flow-state check should block input now
	SceneManager.state = SceneManager.FlowState.MENU
	await _press(&"p1_right")
	assert(select._cursor[0] == 0, "Input should be ignored outside SELECTING flow state")
	SceneManager.state = SceneManager.FlowState.SELECTING

	# --- Close --------------------------------------------------------
	select.close()
	assert(not select.visible)
	assert(select._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	print("PASS: close() hides and stops updating")

	# --- CharacterArt fallback --------------------------------------------
	# No art has been dropped in asset/characters/<id>/ for any fighter yet,
	# so every lookup should report absent and every id should resolve to a
	# valid placeholder rig (the whole point of the art-swap convention).
	for id in CharacterRoster.IDS:
		assert(not CharacterArt.has_portrait(id), "%s should have no portrait yet" % id)
		assert(not CharacterArt.has_select_render(id), "%s should have no select render yet" % id)
		assert(CharacterArt.portrait(id) == null)
		assert(CharacterArt.select_render(id) == null)
		assert(CharacterArt.placeholder_rig(id) != null, "%s must resolve to a placeholder rig" % id)
	print("PASS: CharacterArt falls back to placeholder puppets when files are absent")

	print("PASS: character select rework - all checks passed")
	get_tree().quit()

func _press(action: StringName) -> void:
	# SceneTree.process_frame fires right before Node._process() runs for
	# every node that frame, so resuming from it and pressing immediately
	# guarantees CharacterSelect's own _process() (later this same frame)
	# sees a fresh is_action_just_pressed(). Resuming from a SceneTreeTimer
	# instead (as the trailing wait below does) lands at an unrelated point
	# in the frame, which can land the press after that frame's _process()
	# pass already ran - is_action_just_pressed() is tied to that exact
	# frame index, so it would then never be observed at all.
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().create_timer(0.2).timeout
