extends Node

enum FlowState { MENU, PLAYING, PAUSED, RESULTS, TRANSITIONING }

signal flow_state_changed(state: FlowState)

var state := FlowState.MENU
var _root: GameRoot

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_root(game_root: GameRoot) -> void:
	_root = game_root
	_set_state(FlowState.MENU)

func start_match() -> void:
	if state != FlowState.MENU or not is_instance_valid(_root):
		return
	_set_state(FlowState.TRANSITIONING)
	_clear_injected_input()
	_root.set_menu_spotlight(false)
	_root.music_controller.crossfade_to_game()
	await _root.transition_controller.slide_out(_root.main_menu)
	_root.set_stage_lighting(1.0, 0.45)
	if not _root.arena and not _root.create_match():
		_recover_menu("Unable to prepare match")
		return
	_root.hud.visible = true
	await _root.prepare_match_frame()
	await _root.transition_controller.open_curtain()
	_root.enable_match()
	_set_state(FlowState.PLAYING)

func pause_match() -> void:
	if state != FlowState.PLAYING or not is_instance_valid(_root):
		return
	get_tree().paused = true
	_set_state(FlowState.TRANSITIONING)
	_clear_injected_input()
	_root.music_controller.set_game_ducked(true)
	_root.set_stage_lighting(_root.pause_light_level, 0.2)
	await _root.pause_menu.show_pause(_root.transition_controller.overlay_duration)
	_set_state(FlowState.PAUSED)

func resume_match() -> void:
	if state != FlowState.PAUSED or not is_instance_valid(_root):
		return
	_set_state(FlowState.TRANSITIONING)
	_clear_injected_input()
	await _root.pause_menu.hide_pause(_root.transition_controller.overlay_duration)
	_root.music_controller.set_game_ducked(false)
	_root.set_stage_lighting(1.0, 0.2)
	get_tree().paused = false
	_set_state(FlowState.PLAYING)

func restart_match() -> void:
	if state != FlowState.RESULTS or not is_instance_valid(_root):
		return
	_set_state(FlowState.TRANSITIONING)
	_clear_injected_input()
	await _root.transition_controller.close_curtain()
	_root.win_screen.hide_results()
	if not _root.create_match():
		get_tree().paused = false
		_recover_menu("Unable to restart match")
		return
	_root.hud.visible = true
	await _root.prepare_match_frame()
	_root.enable_match()
	await _root.transition_controller.open_curtain(_root.transition_controller.replay_open_duration)
	_root.music_controller.set_game_ducked(false)
	_root.set_stage_lighting(1.0, 0.2)
	get_tree().paused = false
	_set_state(FlowState.PLAYING)

func return_to_menu() -> void:
	if state not in [FlowState.PAUSED, FlowState.RESULTS] or not is_instance_valid(_root):
		return
	_set_state(FlowState.TRANSITIONING)
	_clear_injected_input()
	await _root.transition_controller.close_curtain()
	_root.set_stage_lighting(_root.menu_light_level, 0.25)
	_root.pause_menu.hide_immediately()
	_root.win_screen.hide_results()
	_root.dispose_match()
	_root.music_controller.crossfade_to_menu()
	get_tree().paused = false
	await _root.transition_controller.slide_in(_root.main_menu)
	_root.set_menu_spotlight(true)
	_set_state(FlowState.MENU)

func show_results(winner_name: String) -> void:
	if state != FlowState.PLAYING or not is_instance_valid(_root):
		return
	get_tree().paused = true
	_set_state(FlowState.TRANSITIONING)
	_clear_injected_input()
	_root.music_controller.set_game_ducked(true)
	_root.set_stage_lighting(_root.pause_light_level, 0.25)
	await _root.win_screen.show_win(winner_name, _root.transition_controller.results_duration)
	_set_state(FlowState.RESULTS)

func quit_game() -> void:
	clear_combat_effects()
	get_tree().quit()

func is_combat_input_enabled() -> bool:
	return state == FlowState.PLAYING and not get_tree().paused

func clear_combat_effects() -> void:
	Juice.reset()
	Sfx.stop_all()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or state == FlowState.TRANSITIONING:
		return
	if state == FlowState.PLAYING:
		pause_match()
	elif state == FlowState.PAUSED:
		resume_match()
	else:
		return
	get_viewport().set_input_as_handled()

func _recover_menu(message: String) -> void:
	push_error(message)
	clear_combat_effects()
	_root.dispose_match()
	_root.transition_controller.set_curtain_closed(true)
	_root.set_stage_lighting(_root.menu_light_level, 0.0)
	_root.pause_menu.hide_immediately()
	_root.win_screen.hide_results()
	_root.main_menu.visible = true
	_root.main_menu.position.x = 0.0
	_root.main_menu.set_menu_active(true)
	_root.set_menu_spotlight(true, true)
	_root.music_controller.crossfade_to_menu()
	get_tree().paused = false
	_set_state(FlowState.MENU)

func _clear_injected_input() -> void:
	if T5Runtime.has_method(&"clear_combat_input"):
		T5Runtime.clear_combat_input()
	for action in [&"p1_attack", &"p2_attack"]:
		Input.action_release(action)

func _set_state(next_state: FlowState) -> void:
	state = next_state
	flow_state_changed.emit(state)
