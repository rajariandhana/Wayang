extends Node

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	var original_enabled: bool = Settings.combo_guide_enabled
	var config_existed := FileAccess.file_exists(Settings.SAVE_PATH)
	var original_config := FileAccess.get_file_as_bytes(Settings.SAVE_PATH) if config_existed else PackedByteArray()
	var game := preload("res://game_root.tscn").instantiate() as GameRoot
	add_child(game)
	await get_tree().process_frame
	assert(game.create_match(&"sura", &"baya"))
	game.main_menu.visible = false
	game.transition_controller.set_curtain_closed(false)
	game.hud.visible = true
	game.set_stage_lighting(1.0, 0.0)
	SceneManager._set_state(SceneManager.FlowState.PLAYING)
	game.enable_match()
	var guide = game.combat_debug
	var panel: SettingsPanel = game.pause_menu.settings_panel
	Settings.set_combo_guide(false)
	assert(not guide.visible)
	panel._handle_menu_button(panel.combo_guide_button)
	assert(Settings.combo_guide_enabled and guide.visible)
	assert(panel.combo_guide_button.text == "Combo guide: On")
	assert(game.main_menu.settings_panel.combo_guide_button.text == "Combo guide: On")
	var cfg := ConfigFile.new()
	assert(cfg.load(Settings.SAVE_PATH) == OK)
	assert(cfg.get_value("gameplay", "combo_guide_enabled", false))
	for pair in [[game.hud.health_bar_1, game.hud.name_1], [game.hud.health_bar_2, game.hud.name_2]]:
		assert(is_equal_approx(pair[0].under.global_position.x, pair[1].global_position.x))
		var before: Vector3 = pair[1].global_position
		pair[0].set_health(35)
		game.hud._position_names()
		assert(pair[1].global_position.is_equal_approx(before), "Name must not move with health fill")
		pair[0].set_health(100)
	assert(guide._arrow("DF", 1.0) == "↘" and guide._arrow("DF", -1.0) == "↙")
	var fighter := game.arena.fighter1
	fighter.set_physics_process(false)
	game.arena.fighter2.set_physics_process(false)
	var now := Time.get_ticks_msec() / 1000.0
	fighter._motion_history = [{"dir": "D", "time": now}, {"dir": "DF", "time": now}]
	var before_history := fighter._motion_history.duplicate(true)
	assert(guide._command_progress(fighter, ["D", "DF", "F"]) == 2)
	assert(fighter._motion_history == before_history, "Guide must never consume combat inputs")
	guide._record("INPUT D | buffer: D", 0)
	guide._record("INPUT DF | buffer: D → DF", 0)
	guide._record("TRIGGER → Sea Spray", 0)
	guide._record("INPUT F | buffer: F", 1)
	guide._record("INPUT D | buffer: F → D", 1)
	guide._record("TRIGGER → River Clamp", 1)
	guide._refresh()
	assert(guide._messages[0] == "SPECIAL: Sea Spray")
	SceneManager._set_state(SceneManager.FlowState.PAUSED)
	assert(not guide.visible)
	SceneManager._set_state(SceneManager.FlowState.PLAYING)
	assert(guide.visible)
	for frame in 3: await get_tree().process_frame
	guide._layout()
	for card in guide._panels:
		assert(card.position.y + card.size.y <= get_viewport().get_visible_rect().size.y / guide._root.scale.y, "Guide card must fit on screen")
	if "--capture-combo" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/combo-guide-match.png")
		SceneManager._set_state(SceneManager.FlowState.MENU)
		game.hud.hide()
		game.main_menu.show()
		game.main_menu._show_panel_immediately(game.main_menu.settings_panel)
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/combo-guide-settings.png")
	game.dispose_match()
	assert(not guide.visible and guide._fighters.is_empty())
	Settings.set_combo_guide(original_enabled)
	# Test the real settings path, then restore the exact user's preference file.
	if config_existed:
		var file := FileAccess.open(Settings.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(original_config)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.SAVE_PATH))
	print("PASS: combo guide settings, persistence, shared panels, flow visibility, mirrored commands, non-consuming progress and centred HUD names")
	get_tree().quit()
