class_name Hurtbox
extends Area2D
# The Damaged: Yang Tersakiti

@export var fighter: Fighter = null
@export var damage_particle: PackedScene = null

var can_be_hit := true

func _on_area_entered(area):
	# print("_on_area_entered hurtbox")
	if not can_be_hit:
		return
	if area is not Hitbox:
		return
	if fighter == area.fighter:
		return
	can_be_hit = false
	fighter.got_hit(area.fighter, area.damage)
	var fx = damage_particle.instantiate()
	add_child(fx)
	fx.position = Vector2(0, -16)
	# Effects.spawn_hit(hit_position)
	await get_tree().create_timer(fighter.hit_cooldown).timeout
	can_be_hit = true

func _on_body_entered(body):
	print("_on_body_entered hurtbox")