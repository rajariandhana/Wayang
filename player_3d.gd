extends MeshInstance3D

@export var tilt_angle: float = 1.5
@export var tilt_speed: float = 2.0

var _time: float = randf_range(0.0, TAU)

func _process(delta):
	_time += delta * tilt_speed
	rotation_degrees.x = sin(_time) * tilt_angle
