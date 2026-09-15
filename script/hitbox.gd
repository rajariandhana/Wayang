class_name Hitbox
extends Area2D
# The Dealer: Yang Menyakiti

@export var fighter: Fighter = null
var damage := 10
## Which vertical band this swing occupies (Combat.Height). The defender's
## stance is checked against it in Hurtbox before any damage is applied.
var height: int = Combat.Height.MID

var is_attacking := false

@onready var _shape: CollisionShape2D = $CollisionShape2D
var _base_shape_scale := Vector2.ONE

func _ready():
	monitoring = false
	if _shape:
		_base_shape_scale = _shape.scale

func start_attack(attack_damage: int, attack_height: int, reach_scale: float = 1.0):
	damage = attack_damage
	height = attack_height
	# Reach is per-move, so it must be reset in end_attack() or it drifts
	# across moves the next time a shorter one is thrown.
	if _shape:
		_shape.scale = _base_shape_scale * reach_scale
	is_attacking = true
	monitoring = true

func end_attack():
	monitoring = false
	is_attacking = false
	if _shape:
		_shape.scale = _base_shape_scale

func set_damage(new_damage:int) -> void:
	damage = new_damage

# hitbox.tscn wires area_entered and body_entered to these. They were connected
# but never defined, which throws "method not found" every time a hurtbox
# touches a live hitbox. Detection lives on the Hurtbox side, so the base
# implementations do nothing on purpose; Projectile overrides _on_area_entered
# because a travelling hitbox does need to know when it connected.
func _on_area_entered(_area: Area2D) -> void:
	pass

func _on_body_entered(_body: Node2D) -> void:
	pass
