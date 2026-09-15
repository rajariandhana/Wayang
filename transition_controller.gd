class_name TransitionController
extends Node

@export var menu_slide_duration := 0.4
@export var menu_slide_distance := 8.0
@export var curtain_open_duration := 0.55
@export var curtain_close_duration := 0.35
@export var replay_open_duration := 0.45
@export var overlay_duration := 0.25
@export var results_duration := 0.35

@onready var curtain: Node3D = $Curtain

var _curtain_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_curtain_closed(closed: bool) -> void:
	_cancel_curtain_tween()
	curtain.set_closed(closed)

func open_curtain(duration := -1.0) -> void:
	await _move_curtain(false, curtain_open_duration if duration < 0.0 else duration)

func close_curtain(duration := -1.0) -> void:
	await _move_curtain(true, curtain_close_duration if duration < 0.0 else duration)

func slide_out(menu: Node3D, duration := -1.0) -> void:
	if not is_instance_valid(menu):
		return
	var seconds := menu_slide_duration if duration < 0.0 else duration
	menu.set_menu_active(false)
	var start_x: float = menu.position.x
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(menu, "position:x", start_x - menu_slide_distance, seconds)
	await tween.finished
	menu.visible = false
	menu.position.x = start_x

func slide_in(menu: Node3D, duration := -1.0) -> void:
	if not is_instance_valid(menu):
		return
	var seconds := menu_slide_duration if duration < 0.0 else duration
	var rest_x: float = menu.position.x
	menu.position.x = rest_x + menu_slide_distance
	menu.visible = true
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(menu, "position:x", rest_x, seconds)
	await tween.finished
	menu.set_menu_active(true)

func _move_curtain(closed: bool, duration: float) -> void:
	_cancel_curtain_tween()
	_curtain_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_curtain_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	curtain.animate_to(_curtain_tween, closed, duration)
	await _curtain_tween.finished
	_curtain_tween = null

func _cancel_curtain_tween() -> void:
	if _curtain_tween and _curtain_tween.is_valid():
		_curtain_tween.kill()
	_curtain_tween = null
