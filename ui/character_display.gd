class_name CharacterDisplay
extends Node2D

## The big side render on the select screen: final art (CharacterArt.select_render)
## when it exists, otherwise a live placeholder puppet with the roster tint.
## The node's origin is where the character's feet stand; target_height is
## the character's full height. Swapping in real art later is just dropping
## files in asset/characters/<id>/ - this re-checks on every set_character().

@export var target_height := 900.0
@export var mirrored := false ## P2 side faces the opposite way.

var _art_sprite: Sprite2D
var _puppet_mount: Node2D
var _puppet: Fighter
var _puppet_rig_path := ""
var _mount_base := Vector2.ZERO
var _bob_phase := randf() * TAU
var _fit_frames := 0

func _ready() -> void:
	_art_sprite = Sprite2D.new()
	_art_sprite.visible = false
	add_child(_art_sprite)
	_puppet_mount = Node2D.new()
	_puppet_mount.visible = false
	add_child(_puppet_mount)

func _process(delta: float) -> void:
	if _fit_frames > 0:
		_fit_frames -= 1
		if _fit_frames == 0:
			_fit_puppet()
	if _puppet_mount.visible:
		_bob_phase += delta * 1.6
		_puppet_mount.position = _mount_base + Vector2(0, sin(_bob_phase) * target_height * 0.006)
		_puppet_mount.rotation = sin(_bob_phase * 0.6) * 0.012

func set_character(id: StringName) -> void:
	modulate = Color.WHITE if CharacterRoster.is_playable(id) else Color.BLACK
	var art := CharacterArt.select_render(id)
	if art:
		_show_art(art)
	else:
		_show_puppet(id)

func refit() -> void:
	if _art_sprite.visible:
		_fit_art()
	elif _puppet_mount.visible:
		_fit_puppet()

func clear() -> void:
	_art_sprite.visible = false
	_puppet_mount.visible = false

func flash_lock() -> void:
	var target: CanvasItem = _art_sprite if _art_sprite.visible else _puppet_mount
	target.modulate = Color(1.7, 1.7, 1.7)
	create_tween().tween_property(target, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _show_art(texture: Texture2D) -> void:
	_puppet_mount.visible = false
	_art_sprite.texture = texture
	_art_sprite.visible = true
	_fit_art()

func _fit_art() -> void:
	var texture := _art_sprite.texture
	if texture == null:
		return
	var s: float = maxf(target_height, 40.0) / maxf(texture.get_height(), 1.0)
	_art_sprite.offset = Vector2(0, -texture.get_height() * 0.5)
	_art_sprite.scale = Vector2(s, s)
	_art_sprite.flip_h = mirrored

func _show_puppet(id: StringName) -> void:
	_art_sprite.visible = false
	# The bare fighter.tscn has no hitbox/skeleton_animation_player wired up
	# (only fighter_1.tscn/fighter_2.tscn assign those node paths), so the
	# preview must use one of the real rigs.
	var rig := CharacterArt.placeholder_rig(id)
	if _puppet == null or _puppet_rig_path != rig.resource_path:
		if _puppet:
			_puppet.queue_free()
		_puppet = rig.instantiate() as Fighter
		_puppet_rig_path = rig.resource_path
		_puppet.preview_mode = true
		_puppet_mount.add_child(_puppet)
	_puppet.configure_character(id)
	_puppet_mount.visible = true
	_fit_puppet()
	# Bone RemoteTransforms settle a frame after the RESET pose; measure again then.
	_fit_frames = 2

func _fit_puppet() -> void:
	if _puppet == null:
		return
	var bounds := _puppet_bounds()
	if bounds.size.y <= 1.0:
		return
	var s: float = maxf(target_height, 40.0) / bounds.size.y
	var sx := -s if mirrored else s
	_puppet_mount.scale = Vector2(sx, s)
	_mount_base = Vector2(-(bounds.position.x + bounds.size.x * 0.5) * sx, -bounds.end.y * s)
	_puppet_mount.position = _mount_base

## Union of the rig's visible sprites in the puppet's own space, skipping the
## control rod so the feet are the baseline. Uses each texture's opaque area:
## the WayangPlayer limb PNGs are full-body canvases that are mostly padding.
func _puppet_bounds() -> Rect2:
	var to_puppet := _puppet.global_transform.affine_inverse()
	var result := Rect2()
	var found := false
	for node in _puppet.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null or not sprite.is_visible_in_tree() or sprite.name in [&"Stick", &"AttackIndicator"]:
			continue
		var xform := to_puppet * sprite.global_transform
		var full := sprite.get_rect()
		var used := _opaque_rect(sprite.texture)
		var rect := Rect2(full.position + used.position * full.size / sprite.texture.get_size(), used.size * full.size / sprite.texture.get_size())
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
			var point: Vector2 = xform * corner
			if found:
				result = result.expand(point)
			else:
				result = Rect2(point, Vector2.ZERO)
				found = true
	return result

static var _opaque_cache := {}

static func _opaque_rect(texture: Texture2D) -> Rect2:
	if not _opaque_cache.has(texture):
		var image := texture.get_image()
		if image == null:
			_opaque_cache[texture] = Rect2(Vector2.ZERO, texture.get_size())
		else:
			if image.is_compressed():
				image.decompress()
			var used := image.get_used_rect()
			_opaque_cache[texture] = Rect2(used) if used.size != Vector2i.ZERO else Rect2(Vector2.ZERO, texture.get_size())
	return _opaque_cache[texture]
