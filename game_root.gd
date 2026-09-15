class_name GameRoot
extends Node3D

const MATCH_SCENE := preload("res://arena/arena_2d.tscn")

@onready var combat_viewport: SubViewport = $Theatre/ArenaBackdrop/SubViewport
@onready var hud: Hud = $HUD
@onready var main_menu: Node3D = $Menus/MainMenu
@onready var pause_menu: Node3D = $Menus/PauseMenu
@onready var win_screen: Node3D = $Menus/WinScreen
@onready var character_select: CharacterSelect = $CharacterSelect
@onready var combat_debug: CanvasLayer = $CombatDebug
@onready var transition_controller: TransitionController = $TransitionController
@onready var music_controller: MusicController = $MusicController
@onready var theatre_lights: Node3D = $Theatre/ArenaBackdrop/Lights
@onready var menu_spotlight: MenuSpotlight = $MenuSpotlight

@export_range(0.0, 1.0) var menu_light_level := 0.06
@export_range(0.0, 1.0) var pause_light_level := 0.48

var lighting_level := 1.0:
	set(value):
		lighting_level = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_apply_lighting_level()
var _lighting_tween: Tween

var arena: Arena2d
var session_id := 0
var selected_p1: StringName = &"anoman"
var selected_p2: StringName = &"dasamuka"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	combat_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hud.visible = false
	combat_debug.visible = false
	main_menu.visible = true
	main_menu.set_menu_active(true)
	pause_menu.set_menu_active(false)
	win_screen.set_menu_active(false)
	character_select.close()
	character_select.connect(&"selections_ready", SceneManager.start_selected_match)
	transition_controller.set_curtain_closed(true)
	lighting_level = menu_light_level
	menu_spotlight.set_active(true, true)
	SceneManager.register_root(self)

func create_match(p1 := selected_p1, p2 := selected_p2) -> bool:
	dispose_match()
	selected_p1 = p1
	selected_p2 = p2
	var instance := MATCH_SCENE.instantiate() as Arena2d
	if instance == null:
		return false
	session_id += 1
	arena = instance
	arena.name = "Arena2d"
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	combat_viewport.add_child(arena)
	arena.configure_fighters(selected_p1, selected_p2)
	var bound_session := session_id
	arena.game_over.connect(func(winner: String) -> void:
		if arena == instance and bound_session == session_id:
			SceneManager.show_results(winner)
	)
	hud.bind(arena.fighter1, arena.fighter2)
	combat_debug.call(&"bind", arena.fighter1, arena.fighter2)
	return true

func show_character_select() -> void:
	character_select.open()

func hide_character_select() -> void:
	character_select.close()

func dispose_match() -> void:
	SceneManager.clear_combat_effects()
	if is_instance_valid(arena):
		arena.queue_free()
		arena = null
	for child in combat_viewport.get_children():
		if child is Arena2d:
			combat_viewport.remove_child(child)
			child.queue_free()
	hud.visible = false
	combat_debug.visible = false
	combat_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func enable_match() -> void:
	if arena:
		arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	combat_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	combat_debug.visible = true

func set_stage_lighting(level: float, duration := 0.35) -> void:
	if _lighting_tween and _lighting_tween.is_valid():
		_lighting_tween.kill()
	if duration <= 0.0:
		lighting_level = level
		return
	_lighting_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_lighting_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_lighting_tween.tween_property(self, "lighting_level", level, duration)

func set_menu_spotlight(active: bool, immediate := false) -> void:
	menu_spotlight.set_active(active, immediate)

func _apply_lighting_level() -> void:
	for light in theatre_lights.get_children():
		if "intensity_multiplier" in light:
			light.set("intensity_multiplier", lighting_level)

func prepare_match_frame() -> void:
	combat_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Yield across a full frame boundary after requesting the viewport update.
	# Unlike frame_post_draw, process_frame also completes in headless tests and
	# when a desktop window is temporarily occluded.
	await get_tree().process_frame
	await get_tree().process_frame
