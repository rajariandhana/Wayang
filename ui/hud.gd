class_name Hud
extends CanvasLayer

## Screen-space HUD.
##
## The health bars used to live inside the 3D diorama: each one rendered into
## its own SubViewport, which fed a ViewportTexture on a Sprite3D. That path
## depends on the renderer keeping those viewports updating, which is fragile
## outside the editor. Drawing them straight to a CanvasLayer keeps the same
## art but removes the round trip entirely.

@onready var health_bar_1: HealthBar = $HealthBar1
@onready var health_bar_2: HealthBar = $HealthBar2

func bind(fighter1: Fighter, fighter2: Fighter) -> void:
	_bind(fighter1, health_bar_1)
	_bind(fighter2, health_bar_2)

func _bind(fighter: Fighter, bar: HealthBar) -> void:
	fighter.health_bar = bar
	bar.setup(fighter.max_health, fighter.health)

func _process(_delta: float) -> void:
	# The pause and win overlays are 3D quads, and a CanvasLayer always draws
	# over the 3D world -- hide the bars while either of them is up.
	visible = not get_tree().paused
