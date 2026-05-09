extends MeshInstance3D

## Player3D -- reacts to the 2D Player's movement.
## Tilt and lag from the bottom (like a wayang held by a stick).
## Attach to Player3D in the main 3D scene.

@export var tilt_max_angle: float = 12.0        # max lean angle in degrees
@export var tilt_speed: float = 6.0             # how fast it leans
@export var lag_speed: float = 5.0              # how fast it catches up horizontally
@export var flip_duration: float = 0.2          # seconds for the flip animation
@export var move_speed_reference: float = 300.0 # should match Wayang move_speed

# path to the 2D player inside SubViewport -- adjust if needed
@onready var player_2d: CharacterBody2D = $"../SubViewport/Player"

var _target_x: float = 0.0
var _is_flipping: bool = false
var _facing_right: bool = true

func _ready():
	_target_x = global_position.x

func _process(delta):
	if not player_2d:
		return

	var vel = player_2d.velocity

	# --- horizontal lag ---
	# convert 2D velocity to 3D world movement
	# adjust scale factor to match your world units
	_target_x += vel.x * delta * 0.01
	global_position.x = lerp(global_position.x, _target_x, lag_speed * delta)

	# --- vertical (jump/gravity) ---
	# mirror 2D y velocity into 3D y position
	# 2D y is flipped (down = positive), so we negate
	global_position.y = lerp(
		global_position.y,
		-player_2d.position.y * 0.01,
		lag_speed * delta
	)

	# --- tilt from bottom (wayang on a stick) ---
	# tilt is based on horizontal velocity, pivoting from base
	var tilt_target = (-vel.x / move_speed_reference) * tilt_max_angle
	rotation_degrees.z = lerp(rotation_degrees.z, tilt_target, tilt_speed * delta)

	# --- flip ---
	var moving_right = vel.x > 10.0
	var moving_left = vel.x < -10.0

	if moving_right and not _facing_right:
		_facing_right = true
		_do_flip(true)
	elif moving_left and _facing_right:
		_facing_right = false
		_do_flip(false)

func _do_flip(to_right: bool):
	if _is_flipping:
		return
	_is_flipping = true

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)

	# squeeze to 0 on Y axis then back -- feels like a wayang flip
	tween.tween_property(self, "scale:x", 0.0, flip_duration * 0.5)
	tween.tween_property(self, "scale:x", 1.0 if to_right else -1.0, flip_duration * 0.5)
	tween.tween_callback(func(): _is_flipping = false)
