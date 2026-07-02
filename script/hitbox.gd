class_name Hitbox
extends Area2D

@export var fighter: Fighter = null
var damage := 10

var is_attacking := false

func _ready():
	monitoring = false

func start_attack():
	is_attacking = true
	monitoring = true

func end_attack():
	is_attacking = false
	monitoring = false

func set_damage(new_damage:int) -> void:
	damage = new_damage
