extends Menu3DBase

@onready var menu_container: Node3D = $MenuContainer
@onready var resume_button: MenuButton3D = $MenuContainer/ResumeButton
@onready var how_to_play_button: MenuButton3D = $MenuContainer/HowToPlayButton
@onready var settings_button: MenuButton3D = $MenuContainer/SettingsButton
@onready var main_menu_button: MenuButton3D = $MenuContainer/MainMenuButton
@onready var quit_button: MenuButton3D = $MenuContainer/QuitButton
@onready var how_to_play_panel: HowToPlayPanel = $HowToPlayPanel
@onready var settings_panel: SettingsPanel = $SettingsPanel

var _rest_y := {}
var _open := false

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [how_to_play_panel, settings_panel])
	how_to_play_panel.back_pressed.connect(_show_main_panel)
	settings_panel.back_pressed.connect(_show_main_panel)
	for btn in _main_buttons():
		_rest_y[btn] = btn.position.y

func _accepts_input() -> bool:
	return _open

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _open:
			if _active_panel != main_panel:
				_show_main_panel()
			else:
				_close()
		else:
			var win_screen := get_parent().get_node_or_null("WinScreen")
			if win_screen and win_screen.visible:
				return
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _on_button_activated(btn: Node3D) -> void:
	if btn == resume_button:
		_close()
	elif btn == how_to_play_button:
		_show_panel(how_to_play_panel)
	elif btn == settings_button:
		_show_panel(settings_panel)
	elif btn == main_menu_button:
		get_tree().paused = false
		SceneManager.change_scene(SceneManager.main_menu)
	elif btn == quit_button:
		get_tree().paused = false
		get_tree().call_deferred("quit")

func _open_menu() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_animate_in()

func _close() -> void:
	_animate_out()

func _main_buttons() -> Array[Node3D]:
	return [resume_button, how_to_play_button, settings_button, main_menu_button, quit_button]

func _animate_in() -> void:
	var buttons := _main_buttons()
	for btn in buttons:
		btn.position.y = _rest_y[btn] - 0.7
	var tween := create_tween().set_parallel(true)
	for i in buttons.size():
		(tween.tween_property(buttons[i], "position:y", _rest_y[buttons[i]], 0.5)
			.set_delay(i * 0.1)
			.set_ease(Tween.EASE_OUT)
			.set_trans(Tween.TRANS_BACK))

func _animate_out() -> void:
	var buttons := _main_buttons()
	buttons.reverse()
	var tween := create_tween().set_parallel(true)
	for i in buttons.size():
		(tween.tween_property(buttons[i], "position:y", _rest_y[buttons[i]] - 0.7, 0.3)
			.set_delay(i * 0.08)
			.set_ease(Tween.EASE_IN)
			.set_trans(Tween.TRANS_BACK))
	await tween.finished
	visible = false
	_open = false
	_show_main_panel()
	get_tree().paused = false
	_hovered = null
	for btn in buttons:
		btn.position.y = _rest_y[btn]
		btn.scale = Vector3.ONE
