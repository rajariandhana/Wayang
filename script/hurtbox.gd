class_name Hurtbox
extends Area2D
# The Damaged: Yang Tersakiti

@export var fighter: Fighter = null
@export var damage_particle: PackedScene = null

func _on_area_entered(area):
	if area is not Hitbox or !area.monitoring or fighter == area.fighter:
		return

	# Stance check happens BEFORE can_be_hit is spent: a dodge should cost the
	# attacker their whole recovery, not grant the defender free invulnerability.
	if fighter.dodges(area.height):
		print(fighter.character_name, " DODGED ", area.fighter.character_name, "'s attack")
		fighter.dodged.emit(area.fighter, area.height)
		return

	if not area.claim_target(fighter):
		return
	fighter.got_hit(area.fighter, area.damage, area.special)
	var fx = damage_particle.instantiate()
	add_child(fx)
	fx.position = Vector2(0, -16)

func _on_body_entered(_body):
	pass
