class_name MenuSpotlight
extends SpotLight3D

@export var base_energy := 3.4
@export var flicker_strength := 0.16
@export var sway_degrees := 4.0
@export var sway_speed := 0.72

var _time := 0.0
var _active_amount := 1.0
var _target_active := 1.0
var _base_rotation := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_rotation = rotation

func _process(delta: float) -> void:
	_time += delta
	_active_amount = move_toward(_active_amount, _target_active, delta * 3.5)
	var slow_flicker := sin(_time * 5.1) * 0.55 + sin(_time * 11.7 + 1.8) * 0.3 + sin(_time * 19.3) * 0.15
	light_energy = base_energy * _active_amount * (1.0 + slow_flicker * flicker_strength)
	var sway := deg_to_rad(sway_degrees)
	rotation.x = _base_rotation.x + sin(_time * sway_speed * 0.73) * sway * 0.28
	rotation.y = _base_rotation.y + sin(_time * sway_speed) * sway

func set_active(active: bool, immediate := false) -> void:
	_target_active = 1.0 if active else 0.0
	if immediate:
		_active_amount = _target_active
