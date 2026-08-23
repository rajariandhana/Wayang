class_name MenuSlider3D
extends MenuControl3D
## Draggable 3D volume-style slider. Click anywhere on the track to jump to
## that value (works for both mouse and the Tilt Five wand's single-click
## contract); dragging the mouse while held keeps updating continuously -
## see Menu3DBase._handle_drag(), which projects the pointer ray onto this
## node's local plane so dragging past either end still clamps correctly
## instead of losing tracking.

signal value_changed(value: float)

const TRACK_HEIGHT := 0.16
const HANDLE_SIZE := 0.26
const HOVER_HANDLE_SCALE := 1.35

const TRACK_FILL := Color(0.13, 0.08, 0.04, 0.9)
const TRACK_BORDER := Color(0.5, 0.36, 0.2, 1.0)
const FILL_FILL := Color(0.85, 0.62, 0.32, 1.0)
const FILL_BORDER := Color(0.98, 0.82, 0.48, 1.0)
const HANDLE_FILL := Color(0.98, 0.93, 0.82, 1.0)
const HANDLE_BORDER := Color(0.85, 0.62, 0.32, 1.0)

@export var track_width: float = 1.8
@export var value: float = 1.0

@onready var track: MeshInstance3D = $Track
@onready var fill: MeshInstance3D = $Fill
@onready var handle: MeshInstance3D = $Handle
@onready var area: Area3D = $Area3D
@onready var collision: CollisionShape3D = $Area3D/CollisionShape3D

var _fill_mat: ShaderMaterial

func _ready() -> void:
	var track_mat := _make_material(TRACK_HEIGHT * 0.5, TRACK_FILL, TRACK_BORDER, 0.01)
	track_mat.render_priority = 10
	track.material_override = track_mat
	track.mesh = _quad(Vector2(track_width, TRACK_HEIGHT))

	_fill_mat = _make_material(TRACK_HEIGHT * 0.5, FILL_FILL, FILL_BORDER, 0.0)
	_fill_mat.render_priority = 11
	fill.material_override = _fill_mat

	var handle_mat := _make_material(HANDLE_SIZE * 0.5, HANDLE_FILL, HANDLE_BORDER, 0.018)
	handle_mat.render_priority = 12
	handle.material_override = handle_mat
	handle.mesh = _quad(Vector2(HANDLE_SIZE, HANDLE_SIZE))

	var shape := BoxShape3D.new()
	shape.size = Vector3(track_width + HANDLE_SIZE, maxf(TRACK_HEIGHT, HANDLE_SIZE) + 0.1, 0.18)
	collision.shape = shape
	area.collision_layer = 1

	_refresh_visual()

func _quad(size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	return mesh

func _make_material(radius: float, fill_color: Color, border_color: Color, border_width: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://ui/rounded_panel.gdshader")
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("border_width", border_width)
	mat.set_shader_parameter("fill_color", fill_color)
	mat.set_shader_parameter("border_color", border_color)
	return mat

func set_value(t: float) -> void:
	value = clampf(t, 0.0, 1.0)
	_refresh_visual()
	value_changed.emit(value)

## Converts a world-space point (a raycast hit, or a ray/plane projection
## while dragging) into a value and applies it.
func set_value_from_point(world_point: Vector3) -> void:
	var local := to_local(world_point)
	var half := track_width * 0.5
	set_value((local.x + half) / track_width)

func _refresh_visual() -> void:
	var fill_width := maxf(track_width * value, 0.001)
	fill.mesh = _quad(Vector2(fill_width, TRACK_HEIGHT))
	_fill_mat.set_shader_parameter("rect_size", Vector2(fill_width, TRACK_HEIGHT))
	fill.position.x = -track_width * 0.5 + fill_width * 0.5
	handle.position.x = -track_width * 0.5 + track_width * value

func play_hover_in() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(handle, "scale", Vector3.ONE * HOVER_HANDLE_SCALE, 0.12)

func play_hover_out() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(handle, "scale", Vector3.ONE, 0.12)
