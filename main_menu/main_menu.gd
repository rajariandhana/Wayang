extends Node3D

const HOVER_TILT_DEG := 3.0
const HOVER_TIME := 0.15
const PRESS_DROP := 0.035
const PRESS_DOWN_TIME := 0.05
const PRESS_UP_TIME := 0.12

# Notice the paths have changed to look inside MenuContainer!
@onready var menu_container = $MenuContainer
@onready var title: Sprite3D = $MenuContainer/Title
@onready var start_btn: Area3D = $MenuContainer/StartButton
@onready var quit_btn: Area3D = $MenuContainer/QuitButton
@onready var how_to_play_btn: Node3D = $MenuContainer/HowToPlayButton
@onready var _area_how_to_play: Area3D = $MenuContainer/HowToPlayButton/Area3D
@onready var how_to_play_panel: Node3D = $HowToPlayPanel
@onready var back_btn: Node3D = $HowToPlayPanel/BackButton
@onready var _area_back: Area3D = $HowToPlayPanel/BackButton/Area3D
@onready var intro_start_audio: AudioStreamPlayer = $IntroStart
@onready var intro_loop_audio: AudioStreamPlayer = $IntroLoop

var max_tilt = deg_to_rad(2)
enum State {IDLE, ANIMATING}
var state = State.IDLE

func _ready():
	# Connect the Click signals
	start_btn.input_event.connect(_on_start_clicked)
	quit_btn.input_event.connect(_on_quit_clicked)
	_area_how_to_play.input_event.connect(_on_how_to_play_clicked)
	_area_back.input_event.connect(_on_back_clicked)
	start_btn.mouse_entered.connect(_hover_in.bind(start_btn))
	start_btn.mouse_exited.connect(_hover_out.bind(start_btn))
	quit_btn.mouse_entered.connect(_hover_in.bind(quit_btn))
	quit_btn.mouse_exited.connect(_hover_out.bind(quit_btn))
	_area_how_to_play.mouse_entered.connect(_hover_in.bind(how_to_play_btn))
	_area_how_to_play.mouse_exited.connect(_hover_out.bind(how_to_play_btn))
	_area_back.mouse_entered.connect(_hover_in.bind(back_btn))
	_area_back.mouse_exited.connect(_hover_out.bind(back_btn))

	# 1. Connect the 'finished' signal of the first track to a custom function
	intro_start_audio.finished.connect(_on_intro_start_finished)
	
	# 2. Play the intro track (if you don't already have 'Autoplay' checked in the Inspector)
	intro_loop_audio.play()


func _process(delta):
	if state == State.ANIMATING:
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


# --- CLICK LOGIC ---
func _on_start_clicked(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press(start_btn)
		_animate_out_and_start()

func _on_quit_clicked(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press(quit_btn)
		SceneManager.quit_game()

func _on_how_to_play_clicked(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press(how_to_play_btn)
		_show_how_to_play()

func _on_back_clicked(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press(back_btn)
		_back_from_how_to_play()

func _show_how_to_play() -> void:
	menu_container.visible = false
	how_to_play_panel.visible = true
	start_btn.input_ray_pickable = false
	quit_btn.input_ray_pickable = false
	_area_how_to_play.input_ray_pickable = false
	_area_back.input_ray_pickable = true

func _back_from_how_to_play() -> void:
	how_to_play_panel.visible = false
	menu_container.visible = true
	start_btn.input_ray_pickable = true
	quit_btn.input_ray_pickable = true
	_area_how_to_play.input_ray_pickable = true
	_area_back.input_ray_pickable = false

# --- HOVER / PRESS MICRO-INTERACTIONS ---
func _hover_in(node: Node3D) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "rotation:z", deg_to_rad(HOVER_TILT_DEG), HOVER_TIME)

func _hover_out(node: Node3D) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "rotation:z", 0.0, HOVER_TIME)

func _press(node: Node3D) -> void:
	var base_y := node.position.y
	var tween := create_tween()
	tween.tween_property(node, "position:y", base_y - PRESS_DROP, PRESS_DOWN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "position:y", base_y, PRESS_UP_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# 3. This function runs automatically the exact moment IntroStart ends
func _on_intro_start_finished():
	intro_loop_audio.play()

# --- THE FLY-AWAY ANIMATION ---
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
	tween.tween_property(how_to_play_btn, "position", Vector3(0, -6, 10), 0.6)
	tween.tween_property(quit_btn, "position", Vector3(5, -2, 10), 0.6)
	
	tween.set_parallel(false)
	tween.tween_interval(0.1) # Tiny buffer to ensure they are off-screen
	await tween.finished
	
	SceneManager.change_scene(SceneManager.game_scene)
