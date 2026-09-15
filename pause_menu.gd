extends Menu3DBase

@onready var menu_container: Node3D = $MenuContainer
@onready var resume_button: MenuButton3D = $MenuContainer/ResumeButton
@onready var how_to_play_button: MenuButton3D = $MenuContainer/HowToPlayButton
@onready var settings_button: MenuButton3D = $MenuContainer/SettingsButton
@onready var main_menu_button: MenuButton3D = $MenuContainer/MainMenuButton
@onready var quit_button: MenuButton3D = $MenuContainer/QuitButton
@onready var how_to_play_panel: HowToPlayPanel = $HowToPlayPanel
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var dark_overlay: MeshInstance3D = $DarkOverlay

var _menu_rest_position := Vector3.ZERO

var _open := false

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [how_to_play_panel, settings_panel])
	how_to_play_panel.back_pressed.connect(_show_main_panel)
	settings_panel.back_pressed.connect(_show_main_panel)
	_menu_rest_position = menu_container.position

func _accepts_input() -> bool:
	return _open

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _open:
			if _active_panel != main_panel:
				_show_main_panel()
			else:
				SceneManager.resume_match()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _on_button_activated(btn: Node3D) -> void:
	if btn == resume_button:
		SceneManager.resume_match()
	elif btn == how_to_play_button:
		_show_panel(how_to_play_panel)
	elif btn == settings_button:
		_show_panel(settings_panel)
	elif btn == main_menu_button:
		SceneManager.return_to_menu()
	elif btn == quit_button:
		SceneManager.quit_game()

func show_pause(duration := 0.25) -> void:
	_open = true
	reset_menu()
	set_menu_active(false)
	visible = true
	dark_overlay.transparency = 1.0
	menu_container.position = _menu_rest_position + Vector3(2.6, 0.0, 0.0)
	menu_container.scale = Vector3.ONE * 0.9
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(dark_overlay, "transparency", 0.0, duration)
	tween.tween_property(menu_container, "position", _menu_rest_position, duration + 0.1)
	tween.tween_property(menu_container, "scale", Vector3.ONE, duration + 0.1)
	await tween.finished
	set_menu_active(true)

func hide_pause(duration := 0.25) -> void:
	set_menu_active(false)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(dark_overlay, "transparency", 1.0, duration)
	tween.tween_property(menu_container, "position", _menu_rest_position + Vector3(2.6, 0.0, 0.0), duration)
	tween.tween_property(menu_container, "scale", Vector3.ONE * 0.9, duration)
	await tween.finished
	hide_immediately()

func hide_immediately() -> void:
	set_menu_active(false)
	visible = false
	_open = false
	dark_overlay.transparency = 0.0
	menu_container.position = _menu_rest_position
	menu_container.scale = Vector3.ONE
	reset_menu()

func _main_buttons() -> Array[Node3D]:
	return [resume_button, how_to_play_button, settings_button, main_menu_button, quit_button]
