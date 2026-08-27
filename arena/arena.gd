extends Node3D

@onready var arena_2d: Arena2d = $ArenaBackdrop/SubViewport/Arena2d
@onready var win_screen: Node3D = $WinScreen
@onready var hud: Hud = $Hud

func _ready() -> void:
	arena_2d.game_over.connect(_on_game_over)
	# Bound here rather than by NodePath in the scene: the fighters live inside
	# a nested scene instance, and the HUD does not, so a path across that
	# boundary is exactly the kind that has resolved to null before.
	hud.bind(arena_2d.fighter1, arena_2d.fighter2)

func _on_game_over(winner_name: String) -> void:
	win_screen.show_win(winner_name)
