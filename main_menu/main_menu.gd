extends Menu3DBase

@onready var menu_container: Node3D = $MenuContainer
@onready var start_btn: MenuButton3D = $MenuContainer/StartButton
@onready var how_to_play_btn: MenuButton3D = $MenuContainer/HowToPlayButton
@onready var settings_btn: MenuButton3D = $MenuContainer/SettingsButton
@onready var quit_btn: MenuButton3D = $MenuContainer/QuitButton
@onready var how_to_play_panel: HowToPlayPanel = $HowToPlayPanel
@onready var settings_panel: SettingsPanel = $SettingsPanel
var max_tilt = deg_to_rad(2)

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [how_to_play_panel, settings_panel])
	how_to_play_panel.back_pressed.connect(_show_main_panel)
	settings_panel.back_pressed.connect(_show_main_panel)

func _accepts_input() -> bool:
	return true

func _process(delta):
	# In Tilt Five the menu is viewed head-tracked on the gameboard; the
	# mouse-driven parallax would just wobble it for the glasses wearer.
	if T5Runtime.t5_active:
		if menu_container.rotation != Vector3.ZERO:
			menu_container.rotation = menu_container.rotation.lerp(Vector3.ZERO, 2.0 * delta)
		return

	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()

	var offset_x = (mouse_pos.x / viewport_size.x) - 0.5
	var offset_y = (mouse_pos.y / viewport_size.y) - 0.5

	var target_rot_x = offset_y * max_tilt
	var target_rot_y = offset_x * max_tilt
	var target_rot_z = offset_x * (max_tilt / 3.0)

	# Changed '5.0' to '2.0'. This makes it glide through the air slowly and organically.
	menu_container.rotation.x = lerp(menu_container.rotation.x, target_rot_x, 2.0 * delta)
	menu_container.rotation.y = lerp(menu_container.rotation.y, target_rot_y, 2.0 * delta)
	menu_container.rotation.z = lerp(menu_container.rotation.z, target_rot_z, 2.0 * delta)

# --- BUTTON LOGIC ---
func _on_button_activated(btn: Node3D) -> void:
	if btn == start_btn:
		SceneManager.start_match()
	elif btn == quit_btn:
		SceneManager.quit_game()
	elif btn == how_to_play_btn:
		_show_panel(how_to_play_panel)
	elif btn == settings_btn:
		_show_panel(settings_panel)
