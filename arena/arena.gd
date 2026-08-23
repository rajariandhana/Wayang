extends Node3D

@onready var arena_2d: Arena2d = $ArenaBackdrop/SubViewport/Arena2d
@onready var win_screen: Node3D = $WinScreen

func _ready() -> void:
	arena_2d.game_over.connect(_on_game_over)

func _on_game_over(winner_name: String) -> void:
	win_screen.show_win(winner_name)
