class_name Hud
extends Node3D

## Gameplay HUD, in world space.
##
## Deliberately Node3D and not CanvasLayer -- see health_bar_3d.gd for why
## screen-space UI cannot reach the Tilt Five display.

@onready var health_bar_1: HealthBar3D = $HealthBar1
@onready var health_bar_2: HealthBar3D = $HealthBar2
@onready var name_1: Label3D = $Name1
@onready var name_2: Label3D = $Name2

func _ready() -> void:
	_position_names()

func _position_names() -> void:
	# HealthBar nodes are anchored at the left end; Under is the plate centre.
	# Use the full plate, not the shrinking fill, so names never drift on damage.
	for pair in [[health_bar_1, name_1], [health_bar_2, name_2]]:
		var plate: Sprite3D = pair[0].under
		var label: Label3D = pair[1]
		var half_height := plate.texture.get_height() * plate.pixel_size * plate.global_basis.y.length() * 0.5
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.global_position = plate.global_position + Vector3(0, half_height + 0.075, 0.01)

func bind(fighter1: Fighter, fighter2: Fighter) -> void:
	_bind(fighter1, health_bar_1)
	_bind(fighter2, health_bar_2)
	name_1.text = "P1  %s" % fighter1.character_name
	name_2.text = "P2  %s" % fighter2.character_name
	_position_names()

func _bind(fighter: Fighter, bar: HealthBar3D) -> void:
	fighter.health_bar = bar
	bar.setup(fighter.max_health, fighter.health)
