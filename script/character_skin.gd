class_name CharacterSkin
extends RefCounted

## Dresses the shared fighter rig (fighter_1.tscn / fighter_2.tscn) in a
## character's own puppet art: body, one upper arm and one lower arm. Both arms
## reuse the same two textures - the front arm (the one carrying the hitbox)
## and the other arm both draw over the body for readable attack silhouettes.
##
## Every puppet in asset/ is drawn facing right, so these numbers are rig pixels
## in that one shared facing, derived from the pivot points on the source
## drawings (shoulder cap, elbow cap, palm) at a scale that stands the feet on
## the same line as the Anoman rig. On a left-facing rig (fighter_2) the whole
## skin is mirrored, so any character works on either side: P1 faces right, P2
## faces left. Every playable character needs an entry here - without one the
## fighter just keeps whatever art its rig scene was built with, which is how
## picking Dasamuka for player 1 used to hand you a red-tinted Anoman.
##
## A key may be given once for both arms ("elbow") or per chain
## ("front_elbow" / "back_elbow"), the per-chain one winning. Sura and Baya are
## drawn hanging straight down and share their arms; Anoman and Dasamuka are
## transcribed from the poses authored in fighter_1.tscn / fighter_2.tscn, which
## are asymmetric and carry rest angles, so those spell each chain out.
## "hit_radius" and "hurtbox_size" are optional: a skin that omits them leaves
## the rig's own authored combat shapes alone.

const SKINS := {
	&"sura": {
		"dir": "res://asset/WayangSura/",
		"body_offset": Vector2(23.4, -36.0),
		"front_shoulder": Vector2(171.2, -167.8),
		"back_shoulder": Vector2(-171.2, -205.8),
		"upper_offset": Vector2(31.6, 75.2),
		"elbow": Vector2(24.0, 157.2),
		"lower_offset": Vector2(41.8, 100.6),
		"hand": Vector2(48.8, 174.8),
		"hit_radius": 34.0,
		"hurtbox_size": Vector2(193.0, 502.0),
		"hurtbox_position": Vector2(0.0, 59.0),
	},
	&"baya": {
		"dir": "res://asset/WayangBaya/",
		"body_offset": Vector2(-36.2, -41.8),
		"front_shoulder": Vector2(145.0, -200.5),
		"back_shoulder": Vector2(-227.5, -159.0),
		"upper_offset": Vector2(2.0, 119.0),
		"elbow": Vector2(-15.0, 235.0),
		"lower_offset": Vector2(42.0, 146.2),
		"hand": Vector2(51.5, 294.0),
		"hit_radius": 36.0,
		"hurtbox_size": Vector2(178.0, 519.0),
		"hurtbox_position": Vector2(0.0, 47.0),
	},
	# Anoman and Dasamuka below are the poses fighter_1.tscn and fighter_2.tscn
	# were authored with, read straight off those scenes (Dasamuka's mirrored
	# into the shared right-facing convention). Worn by their own rig they
	# reproduce it exactly; worn by the other rig they mirror onto it.
	&"anoman": {
		"dir": "res://asset/WayangPlayer/",
		"upper": "forearm.png",
		"lower": "arm.png",
		"body_offset": Vector2(-47.0, 12.0),
		"front_shoulder": Vector2(116.0, -164.0),
		"front_upper_rest": -0.3848068,
		"front_elbow": Vector2(14.0, 216.0),
		"front_lower_rest": 0.7099897,
		"front_hand": Vector2(11.0, 160.0),
		"front_upper_offset": Vector2(-250.0, 177.0),
		"front_lower_offset": Vector2(-212.0, -42.0),
		"back_shoulder": Vector2(-182.0, -168.0),
		"back_upper_rest": 0.7237567,
		"back_elbow": Vector2(9.0, 221.0),
		"back_lower_rest": -0.713456,
		"back_hand": Vector2(14.0, 166.0),
		"back_upper_offset": Vector2(-253.0, 179.0),
		"back_lower_offset": Vector2(-210.0, -36.0),
	},
	&"dasamuka": {
		"dir": "res://asset/WayangDasamuka/",
		"upper": "forearm.png",
		"lower": "arm.png",
		# fighter_2 stands its puppet off the rod rather than on it.
		"hip": Vector2(-71.0, 4.0),
		"body_offset": Vector2(47.0, 12.0),
		"front_shoulder": Vector2(174.0, -129.0),
		"front_upper_rest": -0.4328829,
		"front_elbow": Vector2(1.0, 203.0),
		"front_lower_rest": 0.3599036,
		"front_hand": Vector2(4.0, 196.0),
		"front_upper_offset": Vector2(-13.0, 91.0),
		"front_lower_offset": Vector2(34.0, 134.0),
		"back_shoulder": Vector2(-152.0, -89.0),
		"back_upper_rest": 0.2396211,
		"back_elbow": Vector2(1.0, 201.0),
		"back_lower_rest": -0.6770494,
		"back_hand": Vector2(3.0, 194.0),
		"back_upper_offset": Vector2(-13.0, 90.0),
		"back_lower_offset": Vector2(34.0, 134.0),
	},
}

## Filled in for any key a skin leaves out.
const DEFAULTS := {
	"upper": "upper_arm.png",
	"lower": "lower_arm.png",
	"hip": Vector2.ZERO,
	"upper_rest": 0.0,
	"lower_rest": 0.0,
}

var _sprites: Node2D
var _hip: Node2D
var _hurtbox_shape: CollisionShape2D
var _original_hurt := {}
var _hitbox: Hitbox
var _hit_shape: CollisionShape2D
var _original_hit := {}
## Front/back chains: [upper bone, lower bone, hand bone, upper sprite, lower sprite].
var _front: Array[Node2D] = []
var _back: Array[Node2D] = []
var _body: Sprite2D
var _rig_facing := 1.0
var _original := {}
var _original_order: Array[Node] = []
var active := false

static func has_skin(id: StringName) -> bool:
	return SKINS.has(id)

func _init(fighter: Fighter) -> void:
	_sprites = fighter.get_node(^"Node2D/Sprites")
	_hip = fighter.get_node(^"Node2D/Skeleton2D/Hip")
	_body = _sprites.get_node(^"Body")
	_hurtbox_shape = fighter.get_node_or_null(^"Node2D/Hurtbox/CollisionShape2D")
	if _hurtbox_shape:
		_original_hurt = {"shape": _hurtbox_shape.shape, "position": _hurtbox_shape.position}
	_hitbox = fighter.hitbox
	_hit_shape = _hitbox.get_node(^"CollisionShape2D")
	_original_hit = {"shape": _hit_shape.shape, "position": _hit_shape.position,
		"rotation": _hit_shape.rotation, "scale": _hit_shape.scale}
	var hand := fighter.hitbox.get_parent() as Node2D
	var front_side := String(hand.get_parent().get_parent().name).left(1)
	var back_side := "R" if front_side == "L" else "L"
	_front = _chain(front_side)
	_back = _chain(back_side)
	_rig_facing = signf(_front[0].position.x) if _front[0].position.x != 0.0 else 1.0
	for node in [_hip, _body, _hurtbox_shape] + _front + _back:
		if node == null:
			continue
		var state := {"position": node.position, "rotation": node.rotation}
		if node is Sprite2D:
			state.merge({"texture": node.texture, "offset": node.offset, "flip_h": node.flip_h})
		_original[node] = state
	_original_order.assign(_sprites.get_children())

## One skin value, preferring this chain's own ("front_elbow") over the entry
## shared by both arms ("elbow") over the DEFAULTS.
func _value(skin: Dictionary, key: String, side := ""):
	if side != "" and skin.has(side + "_" + key):
		return skin[side + "_" + key]
	return skin.get(key, DEFAULTS.get(key))

func _reset_combat_shapes() -> void:
	_hit_shape.shape = _original_hit["shape"]
	_hit_shape.position = _original_hit["position"]
	_hit_shape.rotation = _original_hit["rotation"]
	_hit_shape.scale = _original_hit["scale"]
	_hitbox._base_shape_scale = _original_hit["scale"]
	if _hurtbox_shape:
		_hurtbox_shape.shape = _original_hurt["shape"]
		_hurtbox_shape.position = _original_hurt["position"]

func _chain(side: String) -> Array[Node2D]:
	var upper := _hip.get_node(side + "Forearm") as Node2D
	var lower := upper.get_node(side + "Arm") as Node2D
	return [upper, lower, lower.get_node(side + "Hand") as Node2D,
		_sprites.get_node(side + "Forearm") as Node2D, _sprites.get_node(side + "Arm") as Node2D]

func apply(id: StringName) -> void:
	if not SKINS.has(id):
		restore()
		return
	var skin: Dictionary = SKINS[id]
	# The art is always drawn facing right, so it only needs mirroring on a rig
	# that faces left - i.e. whenever this character is worn by fighter 2.
	var mirror := _rig_facing < 0.0
	var mx := func(v: Vector2) -> Vector2: return Vector2(-v.x, v.y) if mirror else v
	# A rotation mirrors by flipping its sign, the same as an x coordinate does.
	var mr := func(r: float) -> float: return -r if mirror else r
	var dir: String = skin["dir"]
	var body_tex := load(dir + "body.png") as Texture2D
	var upper_tex := load(dir + _value(skin, "upper")) as Texture2D
	var lower_tex := load(dir + _value(skin, "lower")) as Texture2D

	_hip.position = mx.call(_value(skin, "hip"))
	_hip.rotation = 0.0
	_dress(_body, body_tex, mx.call(skin["body_offset"]), mirror)
	for chain in [_front, _back]:
		var side := "front" if chain == _front else "back"
		chain[0].position = mx.call(_value(skin, "shoulder", side))
		chain[1].position = mx.call(_value(skin, "elbow", side))
		chain[2].position = mx.call(_value(skin, "hand", side))
		chain[0].rotation = mr.call(_value(skin, "upper_rest", side))
		chain[1].rotation = mr.call(_value(skin, "lower_rest", side))
		chain[2].rotation = 0.0
		_dress(chain[3], upper_tex, mx.call(_value(skin, "upper_offset", side)), mirror)
		_dress(chain[4], lower_tex, mx.call(_value(skin, "lower_offset", side)), mirror)
		# Sprites follow bones through RemoteTransform2D a frame late; snap now
		# so the first rendered frame (and preview bounds) are already right.
		chain[3].global_transform = chain[0].global_transform
		chain[4].global_transform = chain[1].global_transform
	_body.global_transform = _hip.global_transform
	# Start from the rig's authored combat shapes, so switching away from a skin
	# that resized them does not leave the previous character's reach behind.
	_reset_combat_shapes()
	if skin.has("hit_radius"):
		_shape_striking_arm(mx.call(_value(skin, "hand", "front")), float(skin["hit_radius"]))
	# The target a swing has to land on, sized off this puppet's own art in the
	# proportions the Anoman rig uses, so a taller character is not fought
	# against an invisible Anoman-sized torso.
	if _hurtbox_shape and skin.has("hurtbox_size"):
		var rect := RectangleShape2D.new()
		rect.size = skin["hurtbox_size"]
		_hurtbox_shape.shape = rect
		_hurtbox_shape.position = skin["hurtbox_position"]
	# Both complete arm chains are in front of the body. The striking chain
	# draws last where the arms cross; restore() restores the original rig order.
	for limb in [_back[3], _back[4], _front[3], _front[4]]:
		_sprites.move_child(limb, _sprites.get_child_count() - 1)
	active = true

## These arms are long, and a hit only counted where the fist itself landed, so
## a swing whose forearm swept straight through the opponent could whiff. The
## hand keeps the hitbox, but its shape now covers the whole striking forearm,
## elbow to fist. Reach still scales per move: the capsule carries the rig's
## real dimensions, so the node scale is the move's reach multiplier alone.
func _shape_striking_arm(hand_offset: Vector2, radius: float) -> void:
	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = hand_offset.length() + radius * 2.0
	_hit_shape.shape = capsule
	# The elbow sits at -hand_offset in the hand bone's own space.
	_hit_shape.position = -hand_offset * 0.5
	_hit_shape.rotation = atan2(hand_offset.x, -hand_offset.y)
	_hit_shape.scale = Vector2.ONE
	_hitbox._base_shape_scale = Vector2.ONE

func restore() -> void:
	if not active:
		return
	_reset_combat_shapes()
	for node in _original:
		var state: Dictionary = _original[node]
		node.position = state["position"]
		node.rotation = state["rotation"]
		if node is Sprite2D:
			node.texture = state["texture"]
			node.offset = state["offset"]
			node.flip_h = state["flip_h"]
	for i in _original_order.size():
		_sprites.move_child(_original_order[i], i)
	active = false

func _dress(sprite: Sprite2D, texture: Texture2D, offset: Vector2, mirror: bool) -> void:
	sprite.texture = texture
	sprite.offset = offset
	sprite.flip_h = mirror
