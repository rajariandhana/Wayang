extends Node3D

# Notice the paths have changed to look inside MenuContainer!
@onready var menu_container = $MenuContainer
@onready var title = $MenuContainer/Title
@onready var start_btn = $MenuContainer/Start
@onready var quit_btn = $MenuContainer/Quit

var max_tilt = deg_to_rad(2) 
var is_animating = false 

func _ready():
	# Connect the Click signals
	$MenuContainer/Start/Area3D.input_event.connect(_on_start_clicked)
	$MenuContainer/Quit/Area3D.input_event.connect(_on_quit_clicked)
	print("Single Pane Menu is ready!")


func _process(delta):
	if is_animating:
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
func _on_start_clicked(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("START CLICKED")
		_animate_out_and_start()

func _on_quit_clicked(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_tree().quit()


# --- THE FLY-AWAY ANIMATION ---
# --- THE FLY-AWAY ANIMATION ---
func _animate_out_and_start():
	is_animating = true 
	
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
	tween.tween_property(quit_btn, "position", Vector3(5, -2, 10), 0.6)
	
	tween.set_parallel(false)
	tween.tween_interval(0.1) # Tiny buffer to ensure they are off-screen
	await tween.finished
	
	get_tree().change_scene_to_file("res://arena.tscn")
