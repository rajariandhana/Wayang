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

@export var panel_transition_duration := 0.34
@export var panel_transition_offset := 2.6

var main_panel: Node3D
var _active_panel: Node3D
var _area_to_control := {}
var _area_layers := {}
var _hovered: MenuControl3D = null
var _dragging: MenuSlider3D = null
var _menu_active := true
var _panel_transitioning := false
var _panel_positions := {}
var _panel_scales := {}

func _ready() -> void:
	add_to_group(&"t5_pointer_menu")
	for ctrl in _controls_under(self):
		var area := ctrl.get_node_or_null(^"Area3D") as Area3D
		if area:
			_area_to_control[area] = ctrl
			_area_layers[area] = area.collision_layer

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
	_panel_positions[main] = main.position
	_panel_scales[main] = main.scale
	for p in subs:
		_panel_positions[p] = p.position
		_panel_scales[p] = p.scale
		_set_panel_active(p, false)

func _set_panel_active(panel: Node3D, active: bool) -> void:
	panel.visible = active
	_set_panel_interactive(panel, active)

func _set_panel_interactive(panel: Node3D, active: bool) -> void:
	for ctrl in _controls_under(panel):
		var area := ctrl.get_node_or_null(^"Area3D") as Area3D
		if area:
			area.collision_layer = int(_area_layers.get(area, 1)) if active else 0
		if not active:
			ctrl.scale = Vector3.ONE

func _show_panel(panel: Node3D) -> void:
	_transition_panel(panel)

func _show_main_panel() -> void:
	_show_panel(main_panel)

func _transition_panel(panel: Node3D) -> void:
	if _panel_transitioning or panel == _active_panel or not is_instance_valid(panel):
		return
	_panel_transitioning = true
	_clear_pointer_state()
	var outgoing := _active_panel
	# Keep both panels visible for the cross-slide, but make both inert until
	# the motion finishes. Previously _set_panel_active hid the outgoing panel
	# before its first tween frame, making the animation appear broken.
	_set_panel_interactive(outgoing, false)
	var outgoing_rest: Vector3 = _panel_positions.get(outgoing, outgoing.position)
	var incoming_rest: Vector3 = _panel_positions.get(panel, panel.position)
	var outgoing_scale: Vector3 = _panel_scales.get(outgoing, outgoing.scale)
	var incoming_scale: Vector3 = _panel_scales.get(panel, panel.scale)
	var direction := -1.0 if panel == main_panel else 1.0
	panel.position = incoming_rest + Vector3(panel_transition_offset * direction, 0.0, 0.0)
	panel.scale = incoming_scale * 0.92
	panel.visible = true
	_set_panel_interactive(panel, false)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(outgoing, "position:x", outgoing_rest.x - panel_transition_offset * direction, panel_transition_duration)
	tween.tween_property(outgoing, "scale", outgoing_scale * 0.92, panel_transition_duration)
	tween.tween_property(panel, "position", incoming_rest, panel_transition_duration)
	tween.tween_property(panel, "scale", incoming_scale, panel_transition_duration)
	await tween.finished
	outgoing.visible = false
	outgoing.position = outgoing_rest
	outgoing.scale = outgoing_scale
	_active_panel = panel
	_set_panel_interactive(panel, true)
	_panel_transitioning = false

func set_menu_active(active: bool) -> void:
	# This gates input only. Presentation code owns visibility so a menu can be
	# visible-but-inert while it animates. The old implementation called
	# _set_panel_active(..., false), hiding the panel before every flow tween.
	_menu_active = active
	if not active:
		_clear_pointer_state()
	for panel in _panel_positions:
		_set_panel_interactive(panel, active and panel == _active_panel)

func reset_menu() -> void:
	_panel_transitioning = false
	for panel in _panel_positions:
		panel.position = _panel_positions[panel]
		panel.scale = _panel_scales[panel]
	_show_panel_immediately(main_panel)

func _show_panel_immediately(panel: Node3D) -> void:
	for candidate in _panel_positions:
		_set_panel_active(candidate, false)
	_active_panel = panel
	panel.visible = true
	_set_panel_interactive(panel, _menu_active)
	_clear_pointer_state()

func _clear_pointer_state() -> void:
	if _hovered:
		_hovered.play_hover_out()
	_hovered = null
	_dragging = null

# --- Input dispatch (mouse: hover, click, and drag for sliders) -------------

func _input(event: InputEvent) -> void:
	if not wants_pointer():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var result := _raycast(event.position)
			if not result.is_empty() and _area_to_control.has(result.collider):
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
	return _menu_active and not _panel_transitioning and _accepts_input()

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
