extends Node
## Autoload: Sfx. The game's sound effect library.
##
## Two jobs. First, one place to name sounds, so gameplay code says
## `Sfx.play(&"wave_impact")` and never mentions a file path. Swapping the
## placeholder art for real recordings then means editing LIBRARY below and
## touching nothing else.
##
## Second, a pool of players. The old per-fighter AudioStreamPlayer cut its own
## sound off whenever a second hit landed inside the first one's tail, which is
## exactly when a fight is at its loudest.

## Its own bus so an SFX slider can be added later without disturbing music.
## Created at runtime rather than in a default_bus_layout.tres, because the
## project does not have one and adding it would fight the open editor.
## Settings still drives Master, so this stays under the existing volume slider.
const BUS_NAME := "SFX"

## Enough voices for both fighters swinging, two waves in flight and the tails
## of everything that just landed.
const POOL_SIZE := 12

## THE SOUND LIBRARY. This is the table to edit when adding sounds.
##
##   files  : candidates, one picked at random per play, so repeats vary
##   volume : dB offset applied on top of the bus
##   pitch  : random pitch range, the cheapest way to stop repetition fatigue
##
## The `placeholder_*` files are synthesised stand-ins, not final art. See
## COMBAT_MOVESET_DESIGN.md for where to source replacements. Drop new files in
## `asset/sound/`, point the entry at them, and delete the placeholder.
const LIBRARY := {
	# Real recordings already in the project.
	&"hit_body": {
		"files": [
			"res://asset/sound/body hit 1.ogg",
			"res://asset/sound/body hit 2.ogg",
			"res://asset/sound/body hit 3.ogg",
		],
		"volume": 0.0,
		"pitch": Vector2(0.93, 1.07),
	},
	# Layered under a landed hit. A struck bronze gong is what makes this read
	# as wayang rather than as a generic fighting game, so it gets its own
	# channel instead of being baked into the hit sample.
	&"accent": {
		"files": ["res://asset/sound/generated/placeholder_gong.wav"],
		"volume": -7.0,
		"pitch": Vector2(0.96, 1.04),
	},
	&"swing": {
		"files": ["res://asset/sound/generated/placeholder_swing.wav"],
		"volume": -4.0,
		"pitch": Vector2(0.9, 1.12),
	},
	&"dodge": {
		"files": ["res://asset/sound/generated/placeholder_dodge.wav"],
		"volume": -3.0,
		"pitch": Vector2(0.95, 1.1),
	},
	&"wave_launch": {
		"files": ["res://asset/sound/generated/placeholder_wave_launch.wav"],
		"volume": -2.0,
		"pitch": Vector2(0.94, 1.06),
	},
	&"wave_impact": {
		"files": ["res://asset/sound/generated/placeholder_wave_impact.wav"],
		"volume": -1.0,
		"pitch": Vector2(0.92, 1.08),
	},
}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
## Paths that failed to load, so a missing file warns once instead of every
## time the move is thrown.
var _missing := {}

func _ready() -> void:
	# So menu and UI sounds still work once something pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_players.append(player)

func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, "Master")

## Play a named event from LIBRARY. Unknown names warn once and are ignored, so
## a typo never takes the game down mid-match.
func play(event: StringName, volume_offset_db := 0.0) -> void:
	if not LIBRARY.has(event):
		_warn_once("sfx_event_%s" % event, "Sfx: no library entry named '%s'" % event)
		return
	var entry: Dictionary = LIBRARY[event]
	var pitch: Vector2 = entry.get("pitch", Vector2.ONE)
	_play_paths(entry["files"], float(entry.get("volume", 0.0)) + volume_offset_db, pitch)

## Play a random stream from an already-loaded array, for sounds a scene owns
## directly (Fighter.hit_sounds). Same pool, so these no longer cut each other
## off either.
func play_streams(streams: Array[AudioStream], volume_db := 0.0, pitch := Vector2(0.93, 1.07)) -> void:
	if streams.is_empty():
		return
	_emit(streams[randi() % streams.size()], volume_db, pitch)

func _play_paths(paths: Array, volume_db: float, pitch: Vector2) -> void:
	if paths.is_empty():
		return
	var path: String = paths[randi() % paths.size()]
	var stream := _load(path)
	if stream == null:
		return
	_emit(stream, volume_db, pitch)

func _emit(stream: AudioStream, volume_db: float, pitch: Vector2) -> void:
	var player := _take_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(minf(pitch.x, pitch.y), maxf(pitch.x, pitch.y))
	player.play()

## Prefer a free voice; if every one is busy, steal round-robin rather than
## dropping the sound. A stolen tail is less noticeable than a missing impact.
func _take_player() -> AudioStreamPlayer:
	for i in _players.size():
		var idx := (_next + i) % _players.size()
		if not _players[idx].playing:
			_next = (idx + 1) % _players.size()
			return _players[idx]
	var stolen := _players[_next]
	_next = (_next + 1) % _players.size()
	return stolen

func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if _missing.has(path):
		return null
	if not ResourceLoader.exists(path):
		_missing[path] = true
		_warn_once("sfx_path_%s" % path, "Sfx: missing audio file '%s'" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		_missing[path] = true
		_warn_once("sfx_load_%s" % path, "Sfx: '%s' did not load as an AudioStream" % path)
		return null
	_cache[path] = stream
	return stream

## Cut every voice. Called on a scene change so a fire crackle or a gong tail
## does not follow the player into the main menu.
func stop_all() -> void:
	for player in _players:
		player.stop()

func _warn_once(key: String, message: String) -> void:
	if _missing.has(key):
		return
	_missing[key] = true
	push_warning(message)
