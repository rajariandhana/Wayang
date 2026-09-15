class_name CharacterRoster
extends RefCounted

## Combat data is deliberately kept separate from the puppet scene.  The same
## definition can be used by either player and later by finished character art.
const IDS := [&"anoman", &"dasamuka", &"bima", &"arjuna", &"gatotkaca"]

static func all() -> Array[Dictionary]:
	return [definition(id) for id in IDS]

static func definition(id: StringName) -> Dictionary:
	var roster := {
		&"anoman": _fighter("Anoman", "Agile wind fighter", Color("f4eee0"), 0.8, 0.8,
			"Monkey Rush", ["F", "D", "DF"], "Wind Palm", ["D", "DF", "F"], Combat.Height.HIGH, true),
		&"dasamuka": _fighter("Dasamuka", "Heavy king of Alengka", Color("b54138"), 1.2, 1.2,
			"Royal Cleave", ["F", "DF", "D", "DB", "B"], "Alengka Flame", ["D", "DB", "B"], Combat.Height.LOW, true),
		&"bima": _fighter("Bima", "Close-range bruiser", Color("5876b9"), 1.2, 1.2,
			"Pancanaka", ["D", "DF", "F"], "Earth Breaker", ["B", "DB", "D", "DF", "F"], Combat.Height.LOW, true),
		&"arjuna": _fighter("Arjuna", "Precise archer", Color("d1a347"), 1.0, 1.0,
			"Retreating Strike", ["D", "DB", "B"], "Arrow Shot", ["D", "DF", "F"], Combat.Height.HIGH, true),
		&"gatotkaca": _fighter("Gatotkaca", "Sky-borne striker", Color("743f91"), 1.0, 1.1,
			"Sky Fist", ["F", "D", "DF"], "Thunder Palm", ["B", "DB", "D", "DF", "F"], Combat.Height.LOW, true),
	}
	return roster.get(id, roster[&"anoman"]).duplicate(true)

static func _fighter(display_name: String, style: String, tint: Color, speed: float, power: float,
		melee_name: String, melee_motion: Array, ranged_name: String, ranged_motion: Array,
		ranged_height: int, projectile: bool) -> Dictionary:
	return {
		"name": display_name, "style": style, "tint": tint, "speed": speed, "power": power,
		"moves": {
			"neutral": _move("Quick Strike", Combat.Height.MID, 6, 0.10, 0.15, 0.55),
			"up": _move("Rising Strike", Combat.Height.HIGH, 8, 0.12, 0.15, 0.60),
			"down": _move("Low Sweep", Combat.Height.LOW, 10, 0.14, 0.18, 0.65, 1.1, 35.0, 80.0),
			"melee_special": _move(melee_name, Combat.Height.MID, 14, 0.15, 0.18, 1.0, 1.35, 130.0, 0.0, false, melee_motion),
			"ranged_special": _move(ranged_name, ranged_height, 10, 0.20, 0.18, 1.0, 1.0, 30.0, 90.0, projectile, ranged_motion),
		}
	}

static func _move(move_name: String, height: int, damage: int, startup: float, active: float, recovery: float,
		reach := 1.0, lunge := 0.0, drop := 0.0, projectile := false, motion: Array = []) -> Dictionary:
	return {"name": move_name, "height": height, "damage": damage, "startup": startup,
		"active": active, "recovery": recovery, "reach_scale": reach, "lunge": lunge,
		"drop": drop, "projectile": projectile, "motion": motion, "special": not motion.is_empty()}
