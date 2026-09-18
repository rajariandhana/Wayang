extends Node3D
## Gives the backdrop a slow breath so the arena is not a set of perfectly still
## cards behind a moving fight.
##
## A wayang screen is cloth and paper held up in front of a lamp. Nothing in it
## is ever truly still, and a completely static backdrop is one of the things
## that makes a 3D-layered 2D scene read as flat.
##
## Calibration note: do NOT judge amplitudes against the jitter scripts already
## in this scene. castle.gd, dr_angka.gd and the ground's inline script all ship
## at position_strength 0.0008, which at this camera distance is well under one
## pixel. They are effectively switched off. The defaults here are sized to
## actually be seen: roughly 15 to 20 pixels of travel over a seven second
## cycle. Turn `sway_scale` down if it reads as too much.

@export var enabled := true

## One dial for the whole effect, so amplitude can be tuned without touching
## the individual numbers below.
@export_range(0.0, 3.0) var sway_scale := 1.0

## What to sway. Container nodes move everything under them together, which is
## what reads as the screen itself breathing.
@export var targets: Array[NodePath] = [
	^"../CastleAwanSprites",
	^"../Fires",
	^"../ground",
	^"../DrAngka",
]

@export_group("Group sway")
@export var group_tilt_degrees := 1.0
@export var group_drift := Vector3(0.07, 0.04, 0.0)
## Seconds per cycle. Long: a slow drift is felt, a fast one is watched.
@export var group_period := 7.0

@export_group("Per-child sway")
## Individual sprites drifting by different small amounts, which gives parallax
## between the near and far cards so the group does not read as one rigid photo.
@export var sway_children := true
@export var child_tilt_degrees := 0.6
@export var child_drift := Vector3(0.05, 0.03, 0.0)
@export var child_period := 5.0

## Each entry: {node, base_position, base_rotation, phase, gain, tilt, drift,
## period, drives_origin}
var _swayers: Array[Dictionary] = []
var _time := 0.0

func _ready() -> void:
	if not enabled:
		return

	for path in targets:
		var target := get_node_or_null(path) as Node3D
		if target == null:
			push_warning("ArenaSway: no Node3D at '%s'" % path)
			continue

		_add(target, group_tilt_degrees, group_drift, group_period)

		if not sway_children:
			continue

		for child in target.get_children():
			if child is Node3D:
				_add(child, child_tilt_degrees, child_drift, child_period)

## True when a node runs a script that recomputes `position` from a cached
## `_origin_position` every frame (castle.gd, dr_angka.gd, the ground's inline
## jitter). Those we can compose with. See _add.
func _drives_origin(node: Node3D) -> bool:
	return node.get("_origin_position") != null

## Composes with a node's own jitter script instead of fighting it.
##
## Every child of CastleAwanSprites runs castle.gd or awan.gd, and both of those
## recompute `position` from a cached `_origin_position` every single frame.
## Writing `position` on those nodes does nothing at all: they overwrite it the
## same frame. That is why the first version of this script appeared to do
## nothing on the castle.
##
## Driving their cached origin instead means their jitter still runs, on top of
## our sway, and neither script has to know about the other.
func _add(node: Node3D, tilt: float, drift: Vector3, period: float) -> void:
	var drives_origin := _drives_origin(node)

	# A scripted node that does NOT expose an origin is left alone entirely.
	# awan.gd is the reason: it accumulates `position.x += drift * delta` to
	# make the clouds cross the sky, so anything else writing position.x would
	# reset that accumulation every frame and freeze the clouds in place.
	if not drives_origin and node.get_script() != null:
		return

	var base_position: Vector3 = node.get("_origin_position") if drives_origin else node.position
	var base_rotation: Vector3 = node.get("_origin_rotation") if drives_origin else node.rotation

	# Mirrored cards (negative scale) are not tilted: writing `rotation` on a
	# mirrored basis does not always round-trip cleanly and can flip the sprite.
	# A node with an `_origin_rotation` is exempt, because its own script has
	# been round-tripping rotation every frame already and evidently survives it.
	var mirrored := node.transform.basis.determinant() < 0.0

	_swayers.append({
		"node": node,
		"base_position": base_position,
		"base_rotation": base_rotation,
		# Unique phase per node, or the whole backdrop pumps like one object.
		"phase": randf() * TAU,
		# Varied amplitude too, so nothing moves in lockstep even at the same phase.
		"gain": randf_range(0.7, 1.0),
		"tilt": tilt,
		"drift": drift,
		"period": maxf(0.5, period),
		"drives_origin": drives_origin,
		"can_tilt": drives_origin or not mirrored,
	})

func _process(delta: float) -> void:
	_time += delta

	for entry in _swayers:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue

		var t := _time * TAU / float(entry["period"])
		var phase: float = entry["phase"]
		var gain: float = entry["gain"] * sway_scale
		var drift: Vector3 = entry["drift"]

		# Two sines at an awkward ratio, so the loop never lands in an obvious
		# repeat the eye can lock onto.
		var wave_x := sin(t + phase) * 0.7 + sin(t * 1.63 + phase * 1.4) * 0.3
		var wave_y := sin(t * 0.83 + phase * 1.7) * 0.7 + sin(t * 1.31 + phase) * 0.3
		var wave_tilt := sin(t * 0.71 + phase * 0.6) * 0.75 + sin(t * 1.47 + phase) * 0.25

		var offset := Vector3(wave_x * drift.x, wave_y * drift.y, 0.0) * gain
		var swayed_position: Vector3 = entry["base_position"] + offset

		var tilt: float = entry["tilt"]
		var base_rotation: Vector3 = entry["base_rotation"]
		var swayed_rotation := base_rotation
		if tilt > 0.0 and entry["can_tilt"]:
			swayed_rotation.z = base_rotation.z + deg_to_rad(tilt) * wave_tilt * gain

		if entry["drives_origin"]:
			# Its own script reads these next frame and adds its jitter on top.
			node.set("_origin_position", swayed_position)
			node.set("_origin_rotation", swayed_rotation)
		else:
			node.position = swayed_position
			if tilt > 0.0 and entry["can_tilt"]:
				node.rotation.z = swayed_rotation.z
