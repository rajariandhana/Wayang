class_name TheatreCurtain
extends Node3D

@export var closed_left_x := -2.5
@export var closed_right_x := 2.5
@export var open_left_x := -7.2
@export var open_right_x := 7.2
@export var open_scale_x := 0.38
@export var open_scale_y := 1.04
@export var open_rotation := 0.035

@onready var left_panel: MeshInstance3D = $Left
@onready var right_panel: MeshInstance3D = $Right

func set_closed(closed: bool) -> void:
	left_panel.position.x = closed_left_x if closed else open_left_x
	right_panel.position.x = closed_right_x if closed else open_right_x
	left_panel.scale = Vector3.ONE if closed else Vector3(open_scale_x, open_scale_y, 1.0)
	right_panel.scale = Vector3.ONE if closed else Vector3(open_scale_x, open_scale_y, 1.0)
	left_panel.rotation.z = 0.0 if closed else -open_rotation
	right_panel.rotation.z = 0.0 if closed else open_rotation
	_set_open_amount(0.0 if closed else 1.0)

func animate_to(tween: Tween, closed: bool, duration: float) -> void:
	var left_target := closed_left_x if closed else open_left_x
	var right_target := closed_right_x if closed else open_right_x
	tween.tween_property(left_panel, "position:x", left_target, duration)
	tween.tween_property(right_panel, "position:x", right_target, duration)
	var target_scale := Vector3.ONE if closed else Vector3(open_scale_x, open_scale_y, 1.0)
	tween.tween_property(left_panel, "scale", target_scale, duration)
	tween.tween_property(right_panel, "scale", target_scale, duration)
	tween.tween_property(left_panel, "rotation:z", 0.0 if closed else -open_rotation, duration)
	tween.tween_property(right_panel, "rotation:z", 0.0 if closed else open_rotation, duration)
	tween.tween_method(_set_open_amount, _get_open_amount(), 0.0 if closed else 1.0, duration)

func _set_open_amount(value: float) -> void:
	for panel in [left_panel, right_panel]:
		var material := panel.get_active_material(0) as ShaderMaterial
		if material:
			material.set_shader_parameter("open_amount", value)

func _get_open_amount() -> float:
	var material := left_panel.get_active_material(0) as ShaderMaterial
	return float(material.get_shader_parameter("open_amount")) if material else 0.0
