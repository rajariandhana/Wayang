extends Node3D
## Tilt Five wand laser pointer for world-space menu interaction.
##
## Instanced by [T5Runtime] as a child of a rig's wand node (Origin/Wand_1), so
## it inherits the wand's tracked pose. Each physics frame it casts a ray along
## the wand's forward (-Z) axis against the menu button Area3Ds (the same
## colliders the mouse ray-pick uses) and drives hover/click on whichever menu
## is currently accepting pointer input.
##
## Menu contract (see pause_menu.gd / win_screen.gd / main_menu.gd):
##   - the menu root is in group "t5_pointer_menu"
##   - wants_pointer() -> bool     : true while the menu accepts pointer input
##   - pointer_hover(area)         : area is the hovered Area3D, or null
##   - pointer_click(area)         : activate the given Area3D
##
## This script references no Tilt Five types, so it compiles fine on macOS even
## though it is only ever instantiated when glasses are connected.

const MENU_GROUP := &"t5_pointer_menu"
const RAY_LENGTH := 20.0
const RAY_MASK := 1 | 2  # menu buttons live on physics layers 1 (main) and 2 (how-to-play back)

@onready var _laser: MeshInstance3D = _build_laser()
@onready var _dot: MeshInstance3D = _build_dot()

var _hovered_menu: Node = null
var _hovered_area: Area3D = null
var _hovered_point: Vector3 = Vector3.ZERO

func _physics_process(_delta: float) -> void:
	var menu := _active_menu()
	if menu == null:
		_set_visible(false)
		if _hovered_menu and is_instance_valid(_hovered_menu):
			_hovered_menu.call(&"pointer_hover", null)
		_hovered_menu = null
		_hovered_area = null
		return

	var from := global_position
	var dir := -global_transform.basis.z.normalized()
	var to := from + dir * RAY_LENGTH

	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = RAY_MASK
	var result := space.intersect_ray(params)

	var area: Area3D = null
	var hit_menu: Node = null
	var hit_point := to
	if not result.is_empty():
		var collider = result.collider
		if collider is Area3D:
			var owner_menu := _menu_from_area(collider)
			if owner_menu and owner_menu.call(&"wants_pointer"):
				area = collider
				hit_menu = owner_menu
				hit_point = result.position

	# Only report hovers to the menu that owns the hit; clear a stale hover on
	# the previously hovered menu if we've moved off it.
	if hit_menu != _hovered_menu and _hovered_menu and is_instance_valid(_hovered_menu):
		_hovered_menu.call(&"pointer_hover", null)
	_hovered_menu = hit_menu
	_hovered_area = area
	_hovered_point = hit_point
	if hit_menu:
		hit_menu.call(&"pointer_hover", area)

	_update_laser(from, hit_point)
	_set_visible(true)

## Called by T5Runtime when the wand trigger is pressed while a menu is open.
func click() -> void:
	if _hovered_menu and is_instance_valid(_hovered_menu) and _hovered_area:
		_hovered_menu.call(&"pointer_click", _hovered_area, _hovered_point)

func _active_menu() -> Node:
	for m in get_tree().get_nodes_in_group(MENU_GROUP):
		if is_instance_valid(m) and m.has_method(&"wants_pointer") and m.call(&"wants_pointer"):
			return m
	return null

func _menu_from_area(area: Node) -> Node:
	var n: Node = area
	while n:
		if n.is_in_group(MENU_GROUP):
			return n
		n = n.get_parent()
	return null

func _set_visible(v: bool) -> void:
	_laser.visible = v
	_dot.visible = v

func _update_laser(from: Vector3, to: Vector3) -> void:
	var length := maxf(from.distance_to(to), 0.001)
	var dir := (to - from).normalized()
	# Orthonormal basis with +Y along the ray (CylinderMesh is Y-up); uniform
	# scale so there is no shear, and set the cylinder length via the mesh.
	_laser.global_transform = Transform3D(_basis_from_y(dir), (from + to) * 0.5)
	(_laser.mesh as CylinderMesh).height = length
	_dot.global_position = to

func _basis_from_y(y_axis: Vector3) -> Basis:
	var y := y_axis.normalized()
	var up := Vector3.RIGHT if absf(y.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := up.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

func _build_laser() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.004
	mesh.bottom_radius = 0.004
	mesh.height = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _laser_material(Color(1.0, 0.85, 0.4, 0.9))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _build_dot() -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _laser_material(Color(1.0, 0.95, 0.6, 1.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _laser_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_receive_shadows = true
	return mat
