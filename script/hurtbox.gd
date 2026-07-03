class_name Hurtbox
extends Area2D
# The Damaged: Yang Tersakiti

@export var fighter: Fighter = null
@export var damage_particle: PackedScene = null

var can_be_hit := true

func _on_area_entered(area):
	# print("_on_area_entered hurtbox")
	if !can_be_hit or area is not Hitbox or !area.monitoring or fighter == area.fighter:
		return
	can_be_hit = false
	fighter.got_hit(area.fighter, area.damage)
	var fx = damage_particle.instantiate()
	add_child(fx)
	fx.position = Vector2(0, -16)
	# Effects.spawn_hit(hit_position)
	await Util.wait(fighter.ATTACK_COOLDOWN_TIME)
	can_be_hit = true

func _on_body_entered(body):
	print("_on_body_entered hurtbox")
