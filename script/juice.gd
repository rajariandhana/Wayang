extends Node
## Autoload: Juice. Hit feedback: hitstop, screen shake, sprite flash.
##
## Written inline rather than pulled from an addon on purpose. The two obvious
## Godot juice addons want the Forward+ or Mobile renderer and a plain Camera2D;
## this project runs on GL Compatibility and renders its 2D arena into a
## SubViewport shown on a 3D quad, so there is no camera for them to shake.
## Shaking the arena node inside the viewport is what actually works here.

## Hard ceiling on a freeze. Nothing in this game should stop time for longer
## than this, and the watchdog below enforces it even if something asks for more.
const MAX_HITSTOP := 0.25

## Incremented on every hitstop. Only the call still holding the current token
## restores normal speed.
var _hitstop_token := 0
var _hitstop_started_msec := 0
var _shakes: Array[Dictionary] = []

func _ready() -> void:
	# Autoloads are pausable by default. A shake interrupted by the pause menu
	# would freeze mid-offset and leave the arena sitting off-centre, so this
	# one keeps running and always restores the node it moved.
	process_mode = Node.PROCESS_MODE_ALWAYS

## Freeze on impact. Engine.time_scale is global, so this also slows the Tilt
## Five runtime, every attack timer, and every Tween in the game (including the
## menus') for its duration. Keep it short and keep it bounded.
##
## Note that Util.wait uses create_timer, which respects time_scale, so a
## hitstop briefly stretches attack recovery too. That is usually what you want
## (the whole game leans into the hit) but it is a real coupling, not an
## accident, so change it knowingly.
func hitstop(duration := 0.06, scale := 0.15) -> void:
	if duration <= 0.0 or get_tree().paused:
		return
	duration = clampf(duration, 0.0, MAX_HITSTOP)

	# A token, not a clock comparison.
	#
	# The previous version stored a deadline in milliseconds and restored only
	# if Time.get_ticks_msec() had passed it. A SceneTreeTimer counts summed
	# frame deltas, which can satisfy its own duration a millisecond before the
	# integer clock agrees, so the check failed, the restore was skipped, and
	# the entire game stayed at 0.05x speed until the next hit happened to land
	# on the right side of the rounding. That is what the endless slow motion
	# was, and why it followed you into the menus: time_scale also drives the
	# menu button tweens, so a 0.5s animation took ten seconds.
	_hitstop_token += 1
	var token := _hitstop_token
	_hitstop_started_msec = Time.get_ticks_msec()
	Engine.time_scale = clampf(scale, 0.05, 1.0)

	# ignore_time_scale must be true or this timer is slowed by the very freeze
	# it is meant to end.
	await get_tree().create_timer(duration, true, false, true).timeout

	# Overlapping hits extend the freeze rather than cutting each other short:
	# a later hitstop takes the token, so this older call simply does nothing.
	if token == _hitstop_token:
		_end_hitstop()

func _end_hitstop() -> void:
	# Bumping the token invalidates any freeze still awaiting its timer, so
	# nothing can set time_scale back down after we have restored it.
	_hitstop_token += 1
	Engine.time_scale = 1.0

## Watchdog. Two things can otherwise strand a freeze: the tree pausing mid
## hitstop, and a scene change taking away whatever was going to end it.
## Neither should ever leave the player in slow motion, so this always wins.
func _watch_time_scale() -> void:
	if is_equal_approx(Engine.time_scale, 1.0):
		return
	var overdue := Time.get_ticks_msec() - _hitstop_started_msec > int(MAX_HITSTOP * 1000.0) + 100
	if get_tree().paused or overdue:
		_end_hitstop()

## Drop everything and return the game to normal. Called before any scene
## change so nothing bleeds from a match into a menu.
func reset() -> void:
	_end_hitstop()
	for entry in _shakes:
		var target: Node2D = entry["target"]
		if is_instance_valid(target):
			target.position = entry["origin"]
	_shakes.clear()

## Decaying random offset on a node's position. Pass the node whose whole
## contents should move: here that is Arena2d inside the SubViewport, which
## shakes the fighters and floor while leaving the painted backdrop still.
func shake(target: Node2D, strength := 24.0, duration := 0.28) -> void:
	if not is_instance_valid(target) or duration <= 0.0 or get_tree().paused:
		return

	for entry in _shakes:
		if entry["target"] == target:
			# Refresh in place. Starting a second shake would capture the
			# already-displaced position as the origin and the node would walk
			# away from where it belongs.
			entry["strength"] = maxf(float(entry["strength"]), strength)
			entry["duration"] = maxf(float(entry["duration"]), duration)
			entry["elapsed"] = 0.0
			return

	_shakes.append({
		"target": target,
		"origin": target.position,
		"strength": strength,
		"duration": duration,
		"elapsed": 0.0,
	})

func _process(delta: float) -> void:
	_watch_time_scale()

	if _shakes.is_empty():
		return

	# A pause snaps everything back where it belongs rather than leaving the
	# arena sitting a few pixels off centre behind the menu.
	if get_tree().paused:
		for entry in _shakes:
			var paused_target: Node2D = entry["target"]
			if is_instance_valid(paused_target):
				paused_target.position = entry["origin"]
		_shakes.clear()
		return

	var still_running: Array[Dictionary] = []
	for entry in _shakes:
		var target: Node2D = entry["target"]
		if not is_instance_valid(target):
			continue

		entry["elapsed"] = float(entry["elapsed"]) + delta
		var t: float = float(entry["elapsed"]) / float(entry["duration"])
		if t >= 1.0:
			target.position = entry["origin"]
			continue

		# Quadratic falloff: hits hard, settles fast, no lingering wobble.
		var amplitude: float = float(entry["strength"]) * (1.0 - t) * (1.0 - t)
		target.position = entry["origin"] + Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
		still_running.append(entry)

	_shakes = still_running

## Brief bright flash on whatever got hit.
##
## modulate multiplies, so the default 5x clamps almost everything to white on
## GL Compatibility (there is no HDR here for it to bloom into). Lower it if the
## puppets read as blown out rather than struck.
func flash(item: CanvasItem, color := Color(5.0, 5.0, 5.0, 1.0), duration := 0.14) -> void:
	if not is_instance_valid(item) or get_tree().paused:
		return

	# The original colour is remembered on the node, so a second hit landing
	# mid-flash restores to the real colour instead of to the flash colour.
	if not item.has_meta("juice_flash_base"):
		item.set_meta("juice_flash_base", item.modulate)
	var base: Color = item.get_meta("juice_flash_base")

	if item.has_meta("juice_flash_tween"):
		var running = item.get_meta("juice_flash_tween")
		if running is Tween and running.is_valid():
			running.kill()

	var tween := item.create_tween()
	# Runs through a pause. A bound tween would freeze mid-flash and leave the
	# puppet stuck white for as long as the pause menu is open.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	item.set_meta("juice_flash_tween", tween)
	tween.tween_property(item, "modulate", color, duration * 0.2)
	tween.tween_property(item, "modulate", base, duration * 0.8)
