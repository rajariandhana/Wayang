class_name Hitbox
extends Area2D
# The Damager: Yang Menyakiti

@export var fighter: Fighter = null
@export var damage := 10

func _ready():
	monitoring = false

func _on_area_entered(area):
	print("_on_area_entered hitbox")

	# if area is Hurtbox:

	# 	area.take_damage(damage)

func _on_body_entered(body):
	print("_on_body_entered hitbox")