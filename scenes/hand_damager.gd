extends Area2D

# Assign the RigidBody2D that this hand belongs to.
# When null, velocity is estimated from position delta (works with animation-driven arms).
@export var arm_body: RigidBody2D

const SPEED_THRESHOLD := 500.0

signal dealt_hit(area: Area2D, speed: float)

var _velocity   := 0.0
var _prev_pos   := Vector2.ZERO

func _ready() -> void:
	if arm_body == null:
		var p := get_parent()
		while p != null:
			if p is RigidBody2D:
				arm_body = p
				break
			p = p.get_parent()
	_prev_pos = global_position
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if arm_body:
		_velocity = arm_body.linear_velocity.length()
	else:
		# Estimate speed from how far the hand moved this frame.
		_velocity = (global_position - _prev_pos).length() / maxf(delta, 0.0001)
	_prev_pos = global_position

func _on_area_entered(area: Area2D) -> void:
	if _velocity >= SPEED_THRESHOLD:
		dealt_hit.emit(area, _velocity)
