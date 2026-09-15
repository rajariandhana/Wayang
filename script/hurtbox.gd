class_name Hurtbox
extends Area2D
# The Damaged: Yang Tersakiti

@export var fighter: Fighter = null
@export var damage_particle: PackedScene = null

var can_be_hit := true

func _on_area_entered(area):
	if !can_be_hit or area is not Hitbox or !area.monitoring or fighter == area.fighter:
		return

	# Stance check happens BEFORE can_be_hit is spent: a dodge should cost the
	# attacker their whole recovery, not grant the defender free invulnerability.
	if fighter.dodges(area.height):
		print(fighter.character_name, " DODGED ", area.fighter.character_name, "'s attack")
		fighter.dodged.emit(area.fighter, area.height)
		return

	can_be_hit = false
	fighter.got_hit(area.fighter, area.damage)
	var fx = damage_particle.instantiate()
	add_child(fx)
	fx.position = Vector2(0, -16)
	await Util.wait(Combat.HITSTUN_TIME)
	can_be_hit = true

func _on_body_entered(_body):
	pass
