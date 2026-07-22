extends Node3D

const HOVER_TILT_DEG := 3.0
const HOVER_TIME := 0.15
const PRESS_DROP := 0.035
const PRESS_DOWN_TIME := 0.05
const PRESS_UP_TIME := 0.12

@onready var menu_container: Node3D = $MenuContainer
@onready var resume_button: Node3D = $MenuContainer/ResumeButton
@onready var how_to_play_button: Node3D = $MenuContainer/HowToPlayButton
@onready var main_menu_button: Node3D = $MenuContainer/MainMenuButton
@onready var quit_button: Node3D = $MenuContainer/QuitButton
@onready var how_to_play_panel: Node3D = $HowToPlayPanel

@onready var _area_resume: Area3D = $MenuContainer/ResumeButton/Area3D
@onready var _area_htp: Area3D = $MenuContainer/HowToPlayButton/Area3D
@onready var _area_main: Area3D = $MenuContainer/MainMenuButton/Area3D
@onready var _area_quit: Area3D = $MenuContainer/QuitButton/Area3D
@onready var _area_back: Area3D = $HowToPlayPanel/BackButton/Area3D

var _rest_y := {}
var _open := false
var _viewing_how_to_play := false
var _hovered: Node3D = null

func _ready() -> void:
	add_to_group(&"t5_pointer_menu")
	_rest_y[resume_button] = resume_button.position.y
	_rest_y[how_to_play_button] = how_to_play_button.position.y
	_rest_y[main_menu_button] = main_menu_button.position.y
	_rest_y[quit_button] = quit_button.position.y

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _open:
			_handle_hover(event.position)
		return
	if event.is_action_pressed("ui_cancel"):
		if _open:
			if _viewing_how_to_play:
				_back_from_how_to_play()
			else:
				_close()
		else:
			var win_screen := get_parent().get_node_or_null("WinScreen")
			if win_screen and win_screen.visible:
				return
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_handle_click(event.position)

func _raycast(mouse_pos: Vector2, layer_mask: int = 1) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return {}
	var space := get_world_3d().direct_space_state
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 20.0
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = layer_mask
	return space.intersect_ray(params)

func _handle_click(mouse_pos: Vector2) -> void:
	var mask := 2 if _viewing_how_to_play else 1
	var result := _raycast(mouse_pos, mask)
	if result.is_empty():
		return
	pointer_click(result.collider)

func _handle_hover(mouse_pos: Vector2) -> void:
	var mask := 2 if _viewing_how_to_play else 1
	var result := _raycast(mouse_pos, mask)
	pointer_hover(result.collider if not result.is_empty() else null)

# --- Shared pointer interface (mouse ray-pick and Tilt Five wand both feed
#     these; see t5/wand_pointer.gd) ---------------------------------------

## True while this menu should accept pointer input.
func wants_pointer() -> bool:
	return _open

func pointer_hover(area: Object) -> void:
	var btn := _button_for_state(area)
	if btn == _hovered:
		return
	if _hovered:
		_hover_out(_hovered)
	_hovered = btn
	if _hovered:
		_hover_in(_hovered)

func pointer_click(area: Object) -> void:
	var btn := _button_for_state(area)
	if btn == null:
		return
	_press(btn)
	if _viewing_how_to_play:
		if area == _area_back:
			_back_from_how_to_play()
	else:
		if area == _area_resume:
			_close()
		elif area == _area_htp:
			_show_how_to_play()
		elif area == _area_main:
			get_tree().paused = false
			SceneManager.change_scene(SceneManager.main_menu)
		elif area == _area_quit:
			get_tree().paused = false
			get_tree().call_deferred("quit")

## Maps an Area3D to its button node, honouring which panel is currently shown
## so stray pointer hits on hidden buttons (whose colliders stay active) are
## ignored.
func _button_for_state(area: Object) -> Node3D:
	if _viewing_how_to_play:
		if area == _area_back:
			return $HowToPlayPanel/BackButton
		return null
	if area == _area_resume: return resume_button
	elif area == _area_htp: return how_to_play_button
	elif area == _area_main: return main_menu_button
	elif area == _area_quit: return quit_button
	return null

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

func _open_menu() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_animate_in()

func _close() -> void:
	_animate_out()

func _show_how_to_play() -> void:
	_viewing_how_to_play = true
	menu_container.visible = false
	how_to_play_panel.visible = true

func _back_from_how_to_play() -> void:
	_viewing_how_to_play = false
	how_to_play_panel.visible = false
	menu_container.visible = true

func _main_buttons() -> Array[Node3D]:
	return [resume_button, how_to_play_button, main_menu_button, quit_button]

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
	_viewing_how_to_play = false
	how_to_play_panel.visible = false
	menu_container.visible = true
	get_tree().paused = false
	_hovered = null
	for btn in _main_buttons():
		btn.position.y = _rest_y[btn]
		btn.rotation.z = 0.0
