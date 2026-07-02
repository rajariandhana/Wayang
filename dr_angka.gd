extends Node3D

## Subtle handheld jitter effect.
## Attach to any Node3D -- camera, sprite, mesh, etc.

@export var position_strength: float = 0.0008
@export var rotation_strength: float = 0.0004
@export var speed: float = 0.8

var _origin_position: Vector3
var _origin_rotation: Vector3
var _time: float = 0.0

func _ready():
	_origin_position = position
	_origin_rotation = rotation

func _process(delta):
	_time += delta * speed

	# layered noise -- multiple frequencies for organic feel
	var px = _noise(_time * 1.0, 0.0)   - _noise(_time * 2.3, 10.0)
	var py = _noise(_time * 0.9, 20.0)  - _noise(_time * 1.7, 30.0)
	var pz = _noise(_time * 0.7, 40.0)  - _noise(_time * 1.1, 50.0)

	var rx = _noise(_time * 0.6, 60.0)  - _noise(_time * 1.4, 70.0)
	var ry = _noise(_time * 0.5, 80.0)  - _noise(_time * 1.2, 90.0)
	var rz = _noise(_time * 0.8, 100.0) - _noise(_time * 1.9, 110.0)

	position = _origin_position + Vector3(px, py, pz) * position_strength
	rotation = _origin_rotation + Vector3(rx, ry, rz) * rotation_strength

## simple sine-based smooth noise, no FastNoiseLite needed
func _noise(t: float, offset: float) -> float:
	return sin(t * 3.7 + offset) * 0.6 \
		 + sin(t * 7.1 + offset * 1.3) * 0.3 \
		 + sin(t * 13.0 + offset * 0.7) * 0.1
