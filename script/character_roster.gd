class_name CharacterRoster
extends RefCounted

## Combat data is deliberately kept separate from the puppet scene.  The same
## definition can be used by either player and later by finished character art.
const IDS := [&"anoman", &"dasamuka", &"bima", &"arjuna", &"gatotkaca", &"sura", &"baya"]
const COMING_SOON := [&"bima", &"arjuna", &"gatotkaca"]

static func is_playable(id: StringName) -> bool:
	return IDS.has(id) and not COMING_SOON.has(id)

static func playable_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in IDS:
		if is_playable(id): ids.append(id)
	return ids

static func all() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for id in IDS:
		definitions.append(definition(id))
	return definitions

static func definition(id: StringName) -> Dictionary:
	var roster := {
		&"anoman": _fighter("Anoman", "Agile wind fighter", Color("f4eee0"), 1.25, 0.8,
			"Monkey Rush", ["F", "D", "DF"], "Wind Palm", ["D", "DF", "F"], Combat.Height.HIGH, true, "wind"),
		&"dasamuka": _fighter("Dasamuka", "Heavy king of Alengka", Color("b54138"), 0.8, 1.2,
			"Royal Cleave", ["F", "DF", "D", "DB", "B"], "Alengka Flame", ["D", "DB", "B"], Combat.Height.LOW, true, "fire"),
		&"bima": _fighter("Bima", "Close-range bruiser", Color("5876b9"), 0.85, 1.2,
			"Pancanaka", ["D", "DF", "F"], "Earth Breaker", ["B", "DB", "D", "DF", "F"], Combat.Height.LOW, true, "earth"),
		&"arjuna": _fighter("Arjuna", "Precise archer", Color("d1a347"), 1.0, 1.0,
			"Retreating Strike", ["D", "DB", "B"], "Arrow Shot", ["D", "DF", "F"], Combat.Height.HIGH, true, "arrow"),
		&"gatotkaca": _fighter("Gatotkaca", "Sky-borne striker", Color("743f91"), 0.95, 1.1,
			"Sky Fist", ["F", "D", "DF"], "Thunder Palm", ["B", "DB", "D", "DF", "F"], Combat.Height.LOW, true, "thunder"),
		&"sura": _fighter("Sura", "Fast shark of Surabaya", Color("4db8d2"), 1.18, 0.9,
			"Tidal Lunge", ["F", "D", "DF"], "Sea Spray", ["D", "DF", "F"], Combat.Height.HIGH, true, "spray"),
		&"baya": _fighter("Baya", "Heavy crocodile of Surabaya", Color("6f9b4c"), 0.78, 1.25,
			"River Clamp", ["D", "DB", "B"], "Sungai Surge", ["B", "DB", "D", "DF", "F"], Combat.Height.LOW, true, "water", Combat.Height.LOW),
	}
	# Anoman's poses now span startup, contact and recovery. Keep damage intact.
	var anoman_moves: Dictionary = roster[&"anoman"]["moves"]
	var startups := {"neutral": 0.12, "up": 0.16, "down": 0.18, "melee_special": 0.20, "ranged_special": 0.24}
	for key in anoman_moves:
		anoman_moves[key]["presentation"] = key
		anoman_moves[key]["startup"] = startups[key]
	# Wind Palm gathers upright; the previous shared ranged crouch hid the pose.
	anoman_moves["ranged_special"]["drop"] = 0.0
	var dasamuka_moves: Dictionary = roster[&"dasamuka"]["moves"]
	dasamuka_moves["neutral"]["name"] = "Royal Backhand"
	dasamuka_moves["up"]["name"] = "Overhead Crush"
	dasamuka_moves["down"]["name"] = "Low Hook"
	var heavy_startups := {"neutral": 0.18, "up": 0.24, "down": 0.24, "melee_special": 0.30, "ranged_special": 0.32}
	for key in dasamuka_moves:
		dasamuka_moves[key]["presentation"] = key
		dasamuka_moves[key]["animation_style"] = "dasamuka"
		dasamuka_moves[key]["startup"] = heavy_startups[key]
	var aquatic_startups := {
		&"sura": {"neutral": 0.12, "up": 0.15, "down": 0.17, "melee_special": 0.19, "ranged_special": 0.23},
		&"baya": {"neutral": 0.20, "up": 0.24, "down": 0.26, "melee_special": 0.30, "ranged_special": 0.34},
	}
	for aquatic_id in aquatic_startups:
		for key in roster[aquatic_id]["moves"]:
			roster[aquatic_id]["moves"][key]["presentation"] = key
			roster[aquatic_id]["moves"][key]["animation_style"] = String(aquatic_id)
			roster[aquatic_id]["moves"][key]["startup"] = aquatic_startups[aquatic_id][key]
	roster[&"sura"]["moves"]["neutral"]["name"] = "Fin Slice"
	roster[&"sura"]["moves"]["up"]["name"] = "Crest Cutter"
	roster[&"sura"]["moves"]["down"]["name"] = "Undertow Sweep"
	roster[&"baya"]["moves"]["neutral"]["name"] = "Snapping Strike"
	roster[&"baya"]["moves"]["up"]["name"] = "Rising Jaw"
	roster[&"baya"]["moves"]["down"]["name"] = "Riverbed Rake"
	return roster.get(id, roster[&"anoman"]).duplicate(true)

static func _fighter(display_name: String, style: String, tint: Color, speed: float, power: float,
		melee_name: String, melee_motion: Array, ranged_name: String, ranged_motion: Array,
		ranged_height: int, projectile: bool, projectile_profile: String, melee_height := Combat.Height.MID) -> Dictionary:
	var moves := {
		"neutral": _move("Quick Strike", Combat.Height.MID, 6, 0.10, 0.15, 0.55),
		"up": _move("Rising Strike", Combat.Height.HIGH, 8, 0.12, 0.15, 0.60),
		"down": _move("Low Sweep", Combat.Height.LOW, 10, 0.14, 0.18, 0.65, 1.1, 35.0, 80.0),
		"melee_special": _move(melee_name, melee_height, 14, 0.15, 0.18, 1.0, 1.35, 130.0, 0.0, false, melee_motion),
		"ranged_special": _move(ranged_name, ranged_height, 10, 0.20, 0.18, 1.0, 1.0, 30.0, 90.0, projectile, ranged_motion, projectile_profile),
	}
	moves["up"]["anim"] = "attack_up"
	moves["down"]["anim"] = "attack_down"
	moves["melee_special"]["anim"] = "attack_special"
	moves["ranged_special"]["anim"] = "attack_ranged"
	for key in moves:
		var move: Dictionary = moves[key]
		move["damage"] = int(round(float(move["damage"]) * power))
		move["startup"] = float(move["startup"]) / speed
		move["active"] = float(move["active"]) / speed
		move["recovery"] = float(move["recovery"]) / speed
	return {
		"name": display_name, "style": style, "tint": tint, "speed": speed, "power": power,
		"moves": moves
	}

static func _move(move_name: String, height: int, damage: int, startup: float, active: float, recovery: float,
		reach := 1.0, lunge := 0.0, drop := 0.0, projectile := false, motion: Array = [], projectile_profile := "fire") -> Dictionary:
	return {"name": move_name, "height": height, "damage": damage, "startup": startup,
		"active": active, "recovery": recovery, "reach_scale": reach, "lunge": lunge,
		"drop": drop, "projectile": projectile, "motion": motion, "special": not motion.is_empty(), "projectile_profile": projectile_profile, "anim": "attack"}
