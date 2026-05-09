extends Sprite3D

## Attach to Awan1 - Awan4.
## Each cloud drifts horizontally and bobs vertically,
## looping back when it drifts too far.

@export var drift_speed: float = 0.3          # horizontal drift units/sec
@export var drift_direction: float = -1.0     # -1 = left, 1 = right
@export var loop_boundary: float = 15.0       # how far before it wraps back
@export var bob_height: float = 0.08          # vertical bob amplitude
@export var bob_speed: float = 0.5            # vertical bob frequency

## add a random offset so clouds dont all bob in sync
var _time: float = 0.0
var _origin_y: float = 0.0

func _ready():
	_origin_y = position.y
	# randomize phase per cloud so they feel independent
	_time = randf_range(0.0, TAU)

func _process(delta):
	_time += delta

	# horizontal drift
	position.x += drift_speed * drift_direction * delta

	# loop back when out of bounds
	if drift_direction < 0 and position.x < -loop_boundary:
		position.x = loop_boundary
	elif drift_direction > 0 and position.x > loop_boundary:
		position.x = -loop_boundary

	# vertical bob
	position.y = _origin_y + sin(_time * bob_speed) * bob_height
