extends Node

const GAME_SCENE := preload("res://game_root.tscn")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := GAME_SCENE.instantiate() as GameRoot
	add_child(game)
	await get_tree().process_frame

	# Results pauses the tree before the player chooses Change Characters.
	get_tree().paused = true
	SceneManager._set_state(SceneManager.FlowState.RESULTS)
	SceneManager.change_characters()
	assert(not get_tree().paused, "Character select must unpause the scene tree")
	assert(SceneManager.state == SceneManager.FlowState.SELECTING)
	assert(game.character_select.visible)
	assert(SceneManager.is_character_select_input_enabled())

	# Verify that a real selection input reaches the reopened screen.
	await get_tree().process_frame
	Input.action_press(&"p1_right")
	await get_tree().process_frame
	assert(game.character_select._cursor[0] == 1, "P1 should be able to move the cursor after results")
	Input.action_release(&"p1_right")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame
	Input.action_press(&"p1_attack")
	await get_tree().process_frame
	assert(game.character_select._locked[0], "P1 should be able to confirm a character after results")
	Input.action_release(&"p1_attack")
	print("PASS: character select accepts input after results")
	get_tree().quit()
