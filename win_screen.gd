extends Menu3DBase

@onready var menu_container: Node3D = $MenuContainer
@onready var title_label: Label3D = $MenuContainer/TitleLabel
@onready var play_again_button: MenuButton3D = $MenuContainer/PlayAgainButton
@onready var main_menu_button: MenuButton3D = $MenuContainer/MainMenuButton
@onready var quit_button: MenuButton3D = $MenuContainer/QuitButton
@onready var dark_overlay: MeshInstance3D = $DarkOverlay

var _menu_rest_position := Vector3.ZERO

var _open := false

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [])
	_menu_rest_position = menu_container.position

func _accepts_input() -> bool:
	return _open

func show_win(winner_name: String, duration := 0.35) -> void:
	title_label.text = "Draw!" if winner_name == "Draw" else "%s Wins" % winner_name
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

func _on_button_activated(btn: Node3D) -> void:
	if btn == play_again_button:
		SceneManager.restart_match()
	elif btn == main_menu_button:
		SceneManager.return_to_menu()
	elif btn == quit_button:
		SceneManager.quit_game()

func _main_buttons() -> Array[Node3D]:
	return [play_again_button, main_menu_button, quit_button]

func hide_results() -> void:
	set_menu_active(false)
	visible = false
	_open = false
	dark_overlay.transparency = 0.0
	menu_container.position = _menu_rest_position
	menu_container.scale = Vector3.ONE
	reset_menu()
