extends Menu3DBase

@onready var menu_container: Node3D = $MenuContainer
@onready var title: Sprite3D = $MenuContainer/Title
@onready var start_btn: MenuButton3D = $MenuContainer/StartButton
@onready var how_to_play_btn: MenuButton3D = $MenuContainer/HowToPlayButton
@onready var settings_btn: MenuButton3D = $MenuContainer/SettingsButton
@onready var quit_btn: MenuButton3D = $MenuContainer/QuitButton
@onready var how_to_play_panel: HowToPlayPanel = $HowToPlayPanel
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var intro_start_audio: AudioStreamPlayer = $IntroStart
@onready var intro_loop_audio: AudioStreamPlayer = $IntroLoop

var max_tilt = deg_to_rad(2)
enum State {IDLE, ANIMATING}
var state = State.IDLE

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [how_to_play_panel, settings_panel])
	how_to_play_panel.back_pressed.connect(_show_main_panel)
	settings_panel.back_pressed.connect(_show_main_panel)

	# 1. Connect the 'finished' signal of the first track to a custom function
	intro_start_audio.finished.connect(_on_intro_start_finished)

	# 2. Play the intro track (if you don't already have 'Autoplay' checked in the Inspector)
	intro_loop_audio.play()

func _accepts_input() -> bool:
	return state == State.IDLE

func _process(delta):
	if state == State.ANIMATING:
		return

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
		_animate_out_and_start()
	elif btn == quit_btn:
		SceneManager.quit_game()
	elif btn == how_to_play_btn:
		_show_panel(how_to_play_panel)
	elif btn == settings_btn:
		_show_panel(settings_panel)

# 3. This function runs automatically the exact moment IntroStart ends
func _on_intro_start_finished():
	intro_loop_audio.play()

# --- THE FLY-AWAY ANIMATION ---
func _animate_out_and_start():
	state = State.ANIMATING

	var tween = create_tween()
	tween.set_parallel(true)

	# EASE_IN with TRANS_EXPO makes them start slow and violently accelerate past the camera
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_EXPO)

	# Instantly flatten the parent container so they point straight at the camera
	tween.tween_property(menu_container, "rotation", Vector3.ZERO, 0.1)

	# Shoot them towards the camera (Positive Z).
	# We also give them slight X/Y offsets so they "scatter" past the lens instead of colliding in the center.
	# NOTE: If your camera is further back than Z=10, change the '10' to '20' or higher!
	tween.tween_property(title, "position", Vector3(0, 4, 10), 0.7)
	tween.tween_property(start_btn, "position", Vector3(-5, -2, 10), 0.6)
	tween.tween_property(how_to_play_btn, "position", Vector3(-2.2, -6, 10), 0.6)
	tween.tween_property(settings_btn, "position", Vector3(2.2, -6, 10), 0.6)
	tween.tween_property(quit_btn, "position", Vector3(5, -2, 10), 0.6)

	tween.set_parallel(false)
	tween.tween_interval(0.1) # Tiny buffer to ensure they are off-screen
	await tween.finished

	SceneManager.change_scene(SceneManager.game_scene)
