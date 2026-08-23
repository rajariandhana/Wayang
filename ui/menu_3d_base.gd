class_name Menu3DBase
extends Node3D
## Shared controller for every 3D menu (main/pause/win). Owns what used to be
## copy-pasted 3x: the mouse raycast input dispatch (click AND drag, for
## MenuSlider3D), the Tilt Five wand pointer contract (wants_pointer/
## pointer_hover/pointer_click - see t5/wand_pointer.gd), hover/press
## dispatch to MenuControl3D children, and switching between a menu's main
## panel and an optional sub-panel (How To Play, Settings).
##
## Subclasses:
##   - call _init_panels(main_panel, [sub_panel, ...]) once their buttons exist
##   - override _accepts_input() to gate when this menu should react to input
##   - override _on_button_activated(btn) for buttons on their own main panel
## A sub-panel scene (see ui/how_to_play_panel.gd) instead implements
## _handle_menu_button(btn) on itself, so its buttons are handled locally
## without the owning menu needing to know about them.

const RAY_LENGTH := 20.0

var main_panel: Node3D
var _active_panel: Node3D
var _area_to_control := {}
var _hovered: MenuControl3D = null
var _dragging: MenuSlider3D = null

func _ready() -> void:
	add_to_group(&"t5_pointer_menu")
	for ctrl in _controls_under(self):
		var area := ctrl.get_node_or_null(^"Area3D") as Area3D
		if area:
			_area_to_control[area] = ctrl

func _controls_under(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is MenuControl3D:
			result.append(child)
		result.append_array(_controls_under(child))
	return result

## Call once from a subclass's _ready(), after its panel nodes exist.
func _init_panels(main: Node3D, subs: Array) -> void:
	main_panel = main
	_active_panel = main
	_set_panel_active(main, true)
	for p in subs:
		_set_panel_active(p, false)

func _set_panel_active(panel: Node3D, active: bool) -> void:
	panel.visible = active
	for ctrl in _controls_under(panel):
		var area := ctrl.get_node_or_null(^"Area3D") as Area3D
		if area:
			area.collision_layer = 1 if active else 0
		if not active:
			ctrl.scale = Vector3.ONE

func _show_panel(panel: Node3D) -> void:
	if _active_panel:
		_set_panel_active(_active_panel, false)
	_active_panel = panel
	_set_panel_active(panel, true)
	_hovered = null
	_dragging = null

func _show_main_panel() -> void:
	_show_panel(main_panel)

# --- Input dispatch (mouse: hover, click, and drag for sliders) -------------

func _input(event: InputEvent) -> void:
	if not wants_pointer():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			get_viewport().set_input_as_handled()
			_handle_press(event.position)
		else:
			_dragging = null
		return
	if event is InputEventMouseMotion:
		if _dragging:
			_handle_drag(event.position)
		else:
			_handle_hover(event.position)

func _raycast(mouse_pos: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return {}
	var space := get_world_3d().direct_space_state
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 1
	return space.intersect_ray(params)

func _handle_press(mouse_pos: Vector2) -> void:
	var result := _raycast(mouse_pos)
	if result.is_empty():
		return
	var ctrl: MenuControl3D = _area_to_control.get(result.collider)
	if ctrl is MenuSlider3D:
		_dragging = ctrl
	pointer_click(result.collider, result.position)

## Projects the pointer ray onto the dragged slider's own plane, rather than
## re-raycasting its (fixed-size) collider, so dragging past either end of
## the track still clamps cleanly instead of losing tracking.
func _handle_drag(mouse_pos: Vector2) -> void:
	if not is_instance_valid(_dragging):
		_dragging = null
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var normal := -_dragging.global_transform.basis.z
	var denom := dir.dot(normal)
	if absf(denom) < 0.0001:
		return
	var t := (_dragging.global_position - from).dot(normal) / denom
	_dragging.set_value_from_point(from + dir * t)

func _handle_hover(mouse_pos: Vector2) -> void:
	var result := _raycast(mouse_pos)
	pointer_hover(result.collider if not result.is_empty() else null)

# --- Shared pointer interface (mouse ray-pick and Tilt Five wand both feed
#     these; see t5/wand_pointer.gd) ------------------------------------------

## True while this menu should accept pointer input. Override to gate on
## whatever "open" state a subclass has.
func wants_pointer() -> bool:
	return _accepts_input()

func _accepts_input() -> bool:
	return true

func pointer_hover(area: Object) -> void:
	var ctrl: MenuControl3D = _area_to_control.get(area)
	if ctrl == _hovered:
		return
	if _hovered:
		_hovered.play_hover_out()
	_hovered = ctrl
	if _hovered:
		_hovered.play_hover_in()

## world_point is the raycast hit position when known (mouse click, or the
## Tilt Five wand - see t5/wand_pointer.gd) - used to place a slider's value
## at the point actually clicked, rather than always snapping to a default.
func pointer_click(area: Object, world_point = null) -> void:
	var ctrl: MenuControl3D = _area_to_control.get(area)
	if ctrl == null:
		return
	if ctrl is MenuSlider3D:
		var pt: Vector3 = world_point if world_point != null else ctrl.global_position
		ctrl.set_value_from_point(pt)
		return
	ctrl.play_press()
	var handler := _find_local_handler(ctrl)
	if handler:
		handler.call(&"_handle_menu_button", ctrl)
	else:
		_on_button_activated(ctrl)

## Walks up from a control looking for the nearest ancestor (short of this
## menu root) that handles its own buttons locally - e.g. a How To
## Play/Settings sub-panel's Back button, so the owning menu doesn't need a
## case for every sub-panel's internals.
func _find_local_handler(ctrl: Node3D) -> Node:
	var n := ctrl.get_parent()
	while n and n != self:
		if n.has_method(&"_handle_menu_button"):
			return n
		n = n.get_parent()
	return null

## Override for buttons that live directly on this menu's own main panel.
func _on_button_activated(_btn: Node3D) -> void:
	pass
