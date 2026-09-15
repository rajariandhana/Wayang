class_name Projectile
extends Hitbox
## A hitbox that travels instead of staying attached to a hand bone.
##
## Extends Hitbox on purpose: Hurtbox already accepts anything that `is Hitbox`,
## already runs the stance check against `height`, and already ignores hitboxes
## belonging to the same fighter. So a moving Hitbox needs no changes on the
## receiving side at all.

## Travel speed in px/sec. At ~2000 a full-arena shot takes a bit over a second,
## which is enough to react to at range and nearly unreactable point blank.
## That is the intent: it is a zoning tool, not a poke.
@export var speed := 2000.0
## Despawn distance. The widest the arena gets is about 2400px (both fighters
## leaned into opposite corners), so this covers a corner-to-corner shot.
@export var max_range := 2800.0
@export var fade_time := 0.15

var direction := 1.0
var _travelled := 0.0
var _expiring := false
var _profile := "fire"
var _visual_tint := Color.WHITE
var _wave_time := 0.0

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var _trail: CPUParticles2D = get_node_or_null("Trail")
@onready var _burst: CPUParticles2D = get_node_or_null("Burst")

func _ready() -> void:
	super()
	set_physics_process(false)

## Called by the attacking Fighter the moment the move's hitbox goes live.
func launch(source: Fighter, attack_damage: int, attack_height: int, dir: float, is_special := true,
		profile := "fire", tint := Color.WHITE) -> void:
	fighter = source
	_profile = profile
	_visual_tint = tint
	direction = signf(dir)
	if direction == 0.0:
		direction = 1.0

	# The source art is a flame pointing up, rotated a quarter turn so it lies
	# along the floor. The turn is AWAY from the direction of travel: the wide
	# base of the flame leads and the tapering tip trails behind, like a comet.
	# Pointing the tip forward made it read as a candle sliding sideways.
	#
	# flip_h mirrors the flame's own asymmetry, not the travel direction
	# (rotation already handles that). Without it the tip curls one way going
	# right and the other going left, and the two directions look like different
	# attacks.
	if _sprite:
		_sprite.visible = _profile not in ["arrow", "water"]
		_sprite.rotation = 0.0 if _profile == "arrow" else -PI * 0.5 * direction
		_sprite.flip_h = direction < 0.0
		_sprite.modulate = tint
		_sprite.scale = Vector2(1.8, 0.55) if _profile == "water" else Vector2(0.8, 0.8) if _profile == "arrow" else Vector2(1.1, 0.95)
		_sprite.play()
	if _trail:
		_trail.modulate = tint
	if _burst:
		_burst.modulate = tint
	match _profile:
		"arrow": speed = 2800.0
		"water": speed = 1300.0
		"spray": speed = 2300.0
		"thunder": speed = 1800.0
	queue_redraw()

	# local_coords is off, so embers stay where they were born and the wave
	# leaves a trail behind it instead of dragging a clump along.
	if _trail:
		_trail.emitting = true

	Sfx.play(&"wave_launch")

	start_attack(attack_damage, attack_height, 1.0, is_special)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_wave_time += delta
	var step := speed * delta * direction
	position.x += step
	_travelled += absf(step)
	if _travelled >= max_range:
		_expire(false)
	if _profile in ["arrow", "water"]:
		queue_redraw()

func _draw() -> void:
	if _profile == "arrow":
		var shaft_end := Vector2(130.0 * direction, -80.0)
		draw_line(Vector2(0, -80), shaft_end, _visual_tint.lightened(0.35), 10.0)
		var tip := shaft_end + Vector2(36.0 * direction, 0)
		draw_colored_polygon(PackedVector2Array([tip, shaft_end + Vector2(0, -22), shaft_end + Vector2(0, 22)]), _visual_tint)
	elif _profile == "water":
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		var crest := PackedVector2Array()
		for i in 13:
			var x := -180.0 + i * 30.0
			var crest_point := Vector2(x, -80.0 + sin(x * 0.045 + _wave_time * 9.0) * 28.0)
			top.append(crest_point)
			crest.append(crest_point)
			bottom.append(Vector2(x, -20.0 + sin(x * 0.045 + _wave_time * 9.0) * 14.0))
		bottom.reverse()
		top.append_array(bottom)
		draw_colored_polygon(top, _visual_tint.darkened(0.15))
		draw_polyline(crest, _visual_tint.lightened(0.35), 9.0)

func _on_area_entered(area: Area2D) -> void:
	if _expiring or area is not Hurtbox:
		return

	var target: Fighter = area.fighter
	if target == null or target == fighter:
		return

	# Same predicate Hurtbox uses, asked directly rather than inferred from
	# whether damage happened, so signal ordering between the two Area2Ds
	# cannot change the outcome.
	#
	# A dodged shot keeps travelling. Lifting the puppet should let the wave
	# pass underneath, not delete it, which is what makes the dodge read as a
	# dodge rather than as a block.
	if target.dodges(height):
		return

	_expire(true)

## `connected` distinguishes hitting someone from running out of range. Only a
## connection earns an impact: a wave that simply expires should fizzle quietly.
func _expire(connected: bool) -> void:
	if _expiring:
		return
	_expiring = true
	set_physics_process(false)
	end_attack()

	if _trail:
		_trail.emitting = false

	# Freed only once its particles have finished living. Everything emitted is
	# owned by this node, so freeing early would delete the impact mid-burst.
	var linger := fade_time
	if _trail:
		linger = maxf(linger, _trail.lifetime)

	if connected:
		Sfx.play(&"wave_impact")
		Juice.shake(get_parent() as Node2D, 14.0, 0.2)
		if _burst:
			_burst.restart()
			_burst.emitting = true
			linger = maxf(linger, _burst.lifetime + 0.15)

	# Fades the flame only, not the node: alpha on the node would take the
	# particles down with it.
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate:a", 0.0, fade_time)

	await get_tree().create_timer(linger, false).timeout
	queue_free()
