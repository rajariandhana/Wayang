class_name HowToPlayPanel
extends Node3D
## Shared How To Play sub-panel, instanced into both main_menu.tscn and
## pause_menu.tscn so the two copies can no longer drift out of sync with
## each other or with the real input map (see project.godot).

signal back_pressed

@onready var back_button: MenuButton3D = $BackButton
@onready var wand_line: Label3D = $WandLine

func _ready() -> void:
	wand_line.visible = T5Runtime.t5_active
	T5Runtime.t5_state_changed.connect(_on_t5_state_changed)

func _on_t5_state_changed(active: bool) -> void:
	wand_line.visible = active

func _handle_menu_button(btn: Node3D) -> void:
	if btn == back_button:
		back_pressed.emit()
