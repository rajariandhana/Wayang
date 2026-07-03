class_name Hitbox
extends Area2D

@export var fighter: Fighter = null
var damage := 10

var is_attacking := false

func _ready():
	monitoring = false

func start_attack():
	monitoring = true

func end_attack():
	monitoring = false

func set_damage(new_damage:int) -> void:
	damage = new_damage
