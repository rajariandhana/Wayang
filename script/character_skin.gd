class_name CharacterSkin
extends RefCounted

## Dresses the shared fighter rig (fighter_1.tscn / fighter_2.tscn) in a
## character's own puppet art: body, one upper arm and one lower arm. Both arms
## reuse the same two textures - the front arm (the one carrying the hitbox)
## and the other arm both draw over the body for readable attack silhouettes.
##
## Numbers are rig pixels in the art's native facing, derived from the pivot
## points on the source drawings (shoulder cap, elbow cap, palm) at a scale
## that stands the feet on the same line as the Anoman rig. Every limb texture
## hangs straight down from its pivot, which is what the pose animators expect.
## When the rig faces the other way the whole skin is mirrored, so any
## character works on either side.

const SKINS := {
	&"sura": {
		"dir": "res://asset/WayangSura/",
		"facing": 1.0,
		"body_offset": Vector2(23.4, -36.0),
		"front_shoulder": Vector2(171.2, -167.8),
		"back_shoulder": Vector2(-171.2, -205.8),
		"upper_offset": Vector2(31.6, 75.2),
		"elbow": Vector2(24.0, 157.2),
		"lower_offset": Vector2(41.8, 100.6),
		"hand": Vector2(48.8, 174.8),
	},
	&"baya": {
		"dir": "res://asset/WayangBaya/",
		"facing": -1.0,
		"body_offset": Vector2(36.2, -41.8),
		"front_shoulder": Vector2(-145.0, -200.5),
		"back_shoulder": Vector2(227.5, -159.0),
		"upper_offset": Vector2(-2.0, 119.0),
		"elbow": Vector2(15.0, 235.0),
		"lower_offset": Vector2(-42.0, 146.2),
		"hand": Vector2(-51.5, 294.0),
	},
}
const HURTBOX_POSITION := Vector2(0, 68)

var _sprites: Node2D
var _hip: Node2D
var _hurtbox_shape: Node2D
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
	var mirror := float(skin["facing"]) != _rig_facing
	var mx := func(v: Vector2) -> Vector2: return Vector2(-v.x, v.y) if mirror else v
	var dir: String = skin["dir"]
	var body_tex := load(dir + "body.png") as Texture2D
	var upper_tex := load(dir + "upper_arm.png") as Texture2D
	var lower_tex := load(dir + "lower_arm.png") as Texture2D

	_hip.position = Vector2.ZERO
	_hip.rotation = 0.0
	_dress(_body, body_tex, mx.call(skin["body_offset"]), mirror)
	for chain in [_front, _back]:
		var shoulder: Vector2 = skin["front_shoulder"] if chain == _front else skin["back_shoulder"]
		chain[0].position = mx.call(shoulder)
		chain[1].position = mx.call(skin["elbow"])
		chain[2].position = mx.call(skin["hand"])
		for bone in chain.slice(0, 3):
			bone.rotation = 0.0
		_dress(chain[3], upper_tex, mx.call(skin["upper_offset"]), mirror)
		_dress(chain[4], lower_tex, mx.call(skin["lower_offset"]), mirror)
		# Sprites follow bones through RemoteTransform2D a frame late; snap now
		# so the first rendered frame (and preview bounds) are already right.
		chain[3].global_transform = chain[0].global_transform
		chain[4].global_transform = chain[1].global_transform
	_body.global_transform = _hip.global_transform
	if _hurtbox_shape:
		_hurtbox_shape.position = HURTBOX_POSITION
	# Both complete arm chains are in front of the body. The striking chain
	# draws last where the arms cross; restore() restores the original rig order.
	for limb in [_back[3], _back[4], _front[3], _front[4]]:
		_sprites.move_child(limb, _sprites.get_child_count() - 1)
	active = true

func restore() -> void:
	if not active:
		return
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
