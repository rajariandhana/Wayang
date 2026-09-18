class_name MusicController
extends Node

@export var crossfade_duration := 0.8
@export var pause_duck_db := -10.0

@onready var menu_intro: AudioStreamPlayer = $MenuIntro
@onready var menu_loop: AudioStreamPlayer = $MenuLoop
@onready var game_music: AudioStreamPlayer = $GameMusic

var _fade_tween: Tween
var _menu_requested := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_intro.finished.connect(_on_menu_intro_finished)
	play_menu_immediately()

func play_menu_immediately() -> void:
	_cancel_fade()
	_menu_requested = true
	game_music.stop()
	menu_loop.stop()
	menu_intro.volume_db = 0.0
	menu_intro.play()

func crossfade_to_game() -> void:
	_menu_requested = false
	if not game_music.playing:
		game_music.volume_db = -80.0
		game_music.play()
	_crossfade([menu_intro, menu_loop], game_music, 0.0)

func crossfade_to_menu() -> void:
	_menu_requested = true
	if not menu_intro.playing and not menu_loop.playing:
		menu_loop.volume_db = -80.0
		menu_loop.play()
	_crossfade([game_music], menu_loop, 0.0)

func set_game_ducked(ducked: bool) -> void:
	if not game_music.playing:
		return
	_cancel_fade()
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(game_music, "volume_db", pause_duck_db if ducked else 0.0, 0.25)

func _crossfade(from_players: Array, target: AudioStreamPlayer, target_db: float) -> void:
	_cancel_fade()
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	for player in from_players:
		if player.playing:
			_fade_tween.tween_property(player, "volume_db", -80.0, crossfade_duration)
	_fade_tween.tween_property(target, "volume_db", target_db, crossfade_duration)
	_fade_tween.set_parallel(false)
	_fade_tween.tween_callback(_stop_silent_players.bind(from_players))

func _stop_silent_players(players: Array) -> void:
	for player in players:
		player.stop()

func _on_menu_intro_finished() -> void:
	if _menu_requested and not menu_loop.playing:
		menu_loop.volume_db = 0.0
		menu_loop.play()

func _cancel_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
