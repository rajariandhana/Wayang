extends Node3D
## Makes the castle read as smouldering behind the play, rather than as three
## looping flame sprites pinned to a backdrop.
##
## Everything here is built in code at _ready, so there are no new .tscn
## sub-resources or image assets to maintain: the particle sprites are
## GradientTexture2D radial fills generated at runtime.
##
## The whole thing keys off the existing `Fires` node. Move, add or delete a
## flame in the editor and the embers, smoke and firelight follow it, because
## every emitter is placed from the flames that are actually there.
##
## Two rules this file is built around:
##
## 1. Everything spawns BEHIND the puppet screen. This is a shadow puppet game;
##    anything drifting in front of the Player3D quad breaks the illusion and
##    hides the fighters.
## 2. Nothing is allowed to look like modern game VFX. The art is painted, muted
##    and warm, so the effects borrow the scene's own firelight colour, stay
##    dim, and move slowly. Bright saturated particles read as pasted on.

@export var enabled := true
## The node holding the existing AnimatedSprite3D flames.
@export var fires_path: NodePath = ^"../Fires"

## One dial for the whole effect. Scales ember, smoke, firelight and glow
## brightness together, so the layers keep their relative balance while the
## overall presence comes up or down. Turn this up before turning up anything
## individual.
@export_range(0.0, 2.0) var intensity := 0.9

## Distant emitters are dimmed toward this fraction, the way haze washes out
## anything far away. Cheap atmospheric perspective, and the reason the whole
## thing settles into the painting instead of floating on it.
@export_range(0.0, 1.0) var depth_fade := 0.45
@export var depth_fade_start := -0.8
@export var depth_fade_end := -3.0

@export_group("Extra flames")
## Extra passes of each existing flame, varied in phase, facing and size, drawn
## in the SAME PLACE as the flame they came from.
##
## They are not scattered, and that is deliberate. Each frame of FireFrames.png
## is a whole pre-composed cluster (one large flame plus a row of small ones)
## spread across a mostly empty 1920x1080 canvas, and every Fires node was hand
## placed so that cluster lands on a wall. Move a copy in any direction and its
## satellite flames leave the wall and hang in open sky, which is exactly what
## happened. Code cannot know where the castle is; only the layout can.
##
## To add fire somewhere NEW, duplicate a Fires node in the editor and place it.
## This setting is only for making the fires that already exist look busier.
@export var extra_flames_per_fire := 1
## Kept near 1.0. A small copy of a cluster reads as a separate, wrong-scale
## fire rather than as more of the same one.
@export var flame_scale_jitter := Vector2(0.82, 1.0)
@export var flame_clone_dim := 0.8

@export_group("Embers")
@export var embers_per_fire := 12
@export var ember_lifetime := 3.6
@export var ember_rise := 0.28

@export_group("Smoke")
## Smoke carries most of the burning read. It is diffuse and slow, so it fits a
## painted backdrop far better than bright specks do, and it is the layer to
## raise first if this still feels too quiet.
@export var smoke_per_fire := 22
@export var smoke_lifetime := 7.0
@export var smoke_drift := Vector3(0.09, 0.22, 0.0)
@export var smoke_opacity := 0.55
@export var smoke_size := Vector2(0.45, 1.15)

@export_group("Firelight")
## An orange point light per flame. The castle sprites are `shaded`, so this is
## what makes the building look lit by its own fire rather than merely having
## fire drawn on top of it. Deliberately weak: it should bias the castle warm,
## not spotlight it.
@export var lights_enabled := true
@export var light_range := 2.2
@export var light_energy_range := Vector2(0.1, 0.42)

@export_group("Horizon glow")
## A soft wash on the backdrop cloth behind the castle. Wide and very faint on
## purpose: it stands in for a distant fire, and it is also the substitute for
## the WorldEnvironment's volumetric fog, which does not render at all under
## the GL Compatibility renderer this project uses.
@export var glow_enabled := true
@export var glow_size := Vector2(13.0, 5.0)
@export var glow_z := -2.7
@export var glow_y := -0.5
@export var glow_opacity := 0.1

## Sampled from the two OmniLight3Ds already in arena_backdrop.tscn, so the new
## effects sit in the palette the scene was lit with instead of introducing a
## second, more saturated orange.
const SCENE_FIRELIGHT := Color(0.9313727, 0.6572922, 0.2066547)

var _lights: Array[OmniLight3D] = []
var _light_phases: Array[float] = []
var _light_gains: Array[float] = []
var _glow: MeshInstance3D = null
var _glow_base_alpha := 0.0
var _time := 0.0

func _ready() -> void:
	if not enabled:
		return

	var fires := get_node_or_null(fires_path)
	if fires == null:
		push_warning("BurningFX: no Fires node at '%s'" % fires_path)
		return

	# Snapshot before spawning clones, or the loop would keep finding its own
	# children and multiply forever.
	var sources: Array[AnimatedSprite3D] = []
	for child in fires.get_children():
		if child is AnimatedSprite3D:
			sources.append(child)

	if sources.is_empty():
		push_warning("BurningFX: Fires node holds no AnimatedSprite3D")
		return

	for source in sources:
		_desync(source)
		_add_extra_flames(source, fires)
		_add_embers(source)
		_add_smoke(source)
		if lights_enabled:
			_add_firelight(source)

	if glow_enabled:
		_add_horizon_glow()

## The three original flames all sat at frame_progress 0.62156594 with the same
## speed_scale, so they pulsed in perfect lockstep and the eye read them as one
## repeating object. Breaking the sync costs nothing and is still the most
## noticeable single change in this file.
func _desync(sprite: AnimatedSprite3D) -> void:
	var frames := sprite.sprite_frames
	if frames and frames.has_animation(sprite.animation):
		sprite.set_frame_and_progress(randi() % maxi(1, frames.get_frame_count(sprite.animation)), randf())
	sprite.speed_scale = sprite.speed_scale * randf_range(0.75, 1.35)

func _add_extra_flames(source: AnimatedSprite3D, parent: Node) -> void:
	var aabb := source.get_aabb()
	var source_scale_y: float = absf(source.transform.basis.get_scale().y)
	# The line the flames stand on, in the parent's space.
	var footing := source.position.y + aabb.position.y * source_scale_y

	for i in extra_flames_per_fire:
		var clone := source.duplicate() as AnimatedSprite3D
		clone.name = "%s_extra_%d" % [source.name, i]
		parent.add_child(clone)

		# Scaled through the basis rather than by setting `scale`. Two of the
		# existing flames are mirrored (negative X and Z), and assigning to
		# `scale` on a mirrored node loses the flip and pops it around.
		var factor := randf_range(flame_scale_jitter.x, flame_scale_jitter.y)
		clone.transform.basis = source.transform.basis.scaled(Vector3.ONE * factor)

		# Sprite3D pivots at its centre, so shrinking a flame lifts its base off
		# the wall. Re-seat the clone on the same footing its source stands on.
		clone.position = source.position
		clone.position.y = footing - aabb.position.y * absf(clone.transform.basis.get_scale().y)

		clone.flip_h = randf() < 0.5
		clone.modulate = Color(flame_clone_dim, flame_clone_dim, flame_clone_dim, 1.0)
		_desync(clone)

func _add_embers(source: AnimatedSprite3D) -> void:
	var band := _flame_band(source, 0.42)
	var origin: Vector3 = band[0]
	var gain := intensity * _depth_gain(origin.z)

	var p := _make_particles("Embers_%s" % source.name, origin, band[1])
	p.amount = maxi(1, int(embers_per_fire * clampf(intensity, 0.2, 1.5)))
	p.lifetime = ember_lifetime
	p.randomness = 0.8

	p.direction = Vector3.UP
	p.spread = 24.0
	# Slow. Fast specks read as sparks from a modern particle system; embers
	# drifting off a fire that has been burning a while barely move.
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.28
	# Positive Y gravity: embers keep drifting upward on the thermal rather than
	# arcing back down, which is what a real updraught looks like.
	p.gravity = Vector3(0.04, ember_rise, 0.0)
	p.damping_min = 0.1
	p.damping_max = 0.4

	# Specks, not dots. At this size they suggest cinders catching the light
	# instead of drawing themselves to the eye.
	p.scale_amount_min = 0.006
	p.scale_amount_max = 0.016
	p.scale_amount_curve = _falloff_curve()

	# No white-hot core. The brightest an ember gets here is the scene's own
	# firelight amber, which is what keeps them inside the painting.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		_tint(SCENE_FIRELIGHT, 1.0, 0.0 * gain),
		_tint(SCENE_FIRELIGHT, 1.0, 0.55 * gain),
		_tint(SCENE_FIRELIGHT.darkened(0.35), 1.0, 0.3 * gain),
		_tint(SCENE_FIRELIGHT.darkened(0.7), 1.0, 0.0),
	])
	p.color_ramp = gradient

	p.material_override = _particle_material(_radial_texture(48, [0.0, 1.0], [1.0, 0.0]), true)

func _add_smoke(source: AnimatedSprite3D) -> void:
	var band := _flame_band(source, 0.5)
	var origin: Vector3 = band[0]
	var gain := intensity * _depth_gain(origin.z)

	var p := _make_particles("Smoke_%s" % source.name, origin, band[1])
	p.amount = maxi(1, int(smoke_per_fire * clampf(intensity, 0.3, 1.5)))
	p.lifetime = smoke_lifetime
	p.randomness = 0.85

	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.22
	p.gravity = smoke_drift
	p.damping_min = 0.15
	p.damping_max = 0.5
	p.angular_velocity_min = -10.0
	p.angular_velocity_max = 10.0

	# Smoke expands as it rises and cools; a constant-size puff reads as a blob.
	p.scale_amount_min = smoke_size.x
	p.scale_amount_max = smoke_size.y
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.2))
	growth.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = growth

	var lit := SCENE_FIRELIGHT.darkened(0.72)
	var cool := Color(0.17, 0.16, 0.155)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	gradient.colors = PackedColorArray([
		# Lit from below by the fire it just left, then cooling to grey.
		_tint(lit, 1.0, 0.0),
		_tint(lit, 1.0, smoke_opacity * gain),
		_tint(cool, 1.0, 0.0),
	])
	p.color_ramp = gradient

	# Mix, not additive: smoke must occlude, or it glows like more fire.
	p.material_override = _particle_material(_radial_texture(96, [0.0, 0.5, 1.0], [0.6, 0.28, 0.0]), false)

func _add_firelight(source: AnimatedSprite3D) -> void:
	var light := OmniLight3D.new()
	light.name = "FireLight_%s" % source.name
	light.light_color = SCENE_FIRELIGHT
	light.omni_range = light_range
	# Shadows off: these are fill lights, and the scene already has two shadow
	# casters. Under GL Compatibility more shadow maps is the expensive choice.
	light.shadow_enabled = false
	add_child(light)
	var band := _flame_band(source, 0.35)
	light.global_position = band[0] + Vector3(0.0, 0.0, 0.15)

	_lights.append(light)
	_light_phases.append(randf() * TAU)
	_light_gains.append(intensity * _depth_gain(light.global_position.z))

func _add_horizon_glow() -> void:
	_glow = MeshInstance3D.new()
	_glow.name = "HorizonGlow"

	var quad := QuadMesh.new()
	quad.size = glow_size
	_glow.mesh = quad

	var material := _particle_material(_radial_texture(160, [0.0, 0.35, 1.0], [0.7, 0.22, 0.0]), true)
	_glow_base_alpha = glow_opacity * intensity
	material.albedo_color = _tint(SCENE_FIRELIGHT, 1.0, _glow_base_alpha)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_glow.material_override = material

	add_child(_glow)
	# Behind the castle and the flames, in front of the backdrop cloth, so it
	# washes the cloth rather than sitting on top of the scene.
	_glow.position = Vector3(0.0, glow_y, glow_z)

func _process(delta: float) -> void:
	_time += delta

	# Layered sines rather than randf per frame: the light should breathe like a
	# fire, not strobe. Each light gets its own phase so they never pulse together.
	for i in _lights.size():
		var phase: float = _light_phases[i]
		var flicker := 0.55 + 0.28 * sin(_time * 5.1 + phase) + 0.17 * sin(_time * 11.7 + phase * 1.7)
		var energy := lerpf(light_energy_range.x, light_energy_range.y, clampf(flicker, 0.0, 1.0))
		_lights[i].light_energy = energy * _light_gains[i]

	if _glow:
		# Slow and shallow. A visible pulse turns a distant fire into a beacon.
		var pulse := 0.9 + 0.1 * sin(_time * 1.1) + 0.04 * sin(_time * 3.3)
		var material := _glow.material_override as StandardMaterial3D
		if material:
			material.albedo_color = _tint(SCENE_FIRELIGHT, 1.0, _glow_base_alpha * pulse)

## Atmospheric perspective. Anything deeper in the scene is washed out toward
## `depth_fade`, so the far fires sit back instead of punching through.
func _depth_gain(z: float) -> float:
	var t := inverse_lerp(depth_fade_start, depth_fade_end, z)
	return lerpf(1.0, depth_fade, clampf(t, 0.0, 1.0))

func _tint(base: Color, value: float, alpha: float) -> Color:
	return Color(base.r * value, base.g * value, base.b * value, alpha)

## Where a flame sprite's fire actually is.
##
## Each atlas frame is a cluster spread across a large, mostly transparent
## canvas, so the node's origin sits in empty space above and beside the flames.
## Emitting from that origin put the smoke in the wrong place. This returns a
## wide, shallow band across the lower part of the sprite instead, so smoke and
## embers rise from the whole cluster rather than from one point in the air.
func _flame_band(source: AnimatedSprite3D, height_fraction: float) -> Array:
	var aabb := source.get_aabb()
	var s: Vector3 = source.transform.basis.get_scale().abs()

	var centre := source.global_position + Vector3(
		aabb.get_center().x * s.x,
		(aabb.position.y + aabb.size.y * height_fraction) * s.y,
		0.0
	)
	var extents := Vector3(
		maxf(0.05, aabb.size.x * s.x * 0.26),
		maxf(0.03, aabb.size.y * s.y * 0.05),
		0.08
	)
	return [centre, extents]

func _make_particles(node_name: String, world_position: Vector3, extents := Vector3(0.14, 0.06, 0.08)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	# CPU rather than GPU particles: this project renders with GL Compatibility,
	# where CPUParticles3D is the option guaranteed to behave the same way in
	# the editor, in an export and on the Tilt Five.
	p.emitting = true
	# World space, so a rising ember keeps rising from where it was born instead
	# of being dragged along if its emitter ever moves.
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.mesh = QuadMesh.new()
	add_child(p)
	p.global_position = world_position
	return p

func _particle_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Without this the per-particle colour ramp is thrown away and every ember
	# comes out the same flat white.
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	return material

## A soft round sprite with no image file behind it.
func _radial_texture(size: int, offsets: Array, alphas: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	var offset_array := PackedFloat32Array()
	var color_array := PackedColorArray()
	for i in offsets.size():
		offset_array.append(float(offsets[i]))
		color_array.append(Color(1.0, 1.0, 1.0, float(alphas[i])))
	gradient.offsets = offset_array
	gradient.colors = color_array

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = size
	texture.height = size
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

## Embers come up gently, then shrink away.
func _falloff_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.1))
	return curve
