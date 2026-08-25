extends Menu3DBase

@onready var menu_container: Node3D = $MenuContainer
@onready var title_label: Label3D = $MenuContainer/TitleLabel
@onready var play_again_button: MenuButton3D = $MenuContainer/PlayAgainButton
@onready var main_menu_button: MenuButton3D = $MenuContainer/MainMenuButton
@onready var quit_button: MenuButton3D = $MenuContainer/QuitButton

var _rest_y := {}
var _open := false

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [])
	for btn in _main_buttons():
		_rest_y[btn] = btn.position.y

func _accepts_input() -> bool:
	return _open

func show_win(winner_name: String) -> void:
	title_label.text = "Draw!" if winner_name == "Draw" else "%s Wins" % winner_name
	_open = true
	visible = true
	get_tree().paused = true
	_animate_in()

func _on_button_activated(btn: Node3D) -> void:
	if btn == play_again_button:
		get_tree().paused = false
		SceneManager.change_scene(SceneManager.game_scene)
	elif btn == main_menu_button:
		get_tree().paused = false
		SceneManager.change_scene(SceneManager.main_menu)
	elif btn == quit_button:
		get_tree().paused = false
		get_tree().call_deferred("quit")

func _main_buttons() -> Array[Node3D]:
	return [play_again_button, main_menu_button, quit_button]

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
