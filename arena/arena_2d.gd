class_name Arena2d
extends StaticBody2D

signal game_over(winner_name: String)

@onready var fighter1: Fighter = $Fighter1
@onready var fighter2: Fighter = $Fighter2

var _game_over := false

func _ready() -> void:
	fighter1.died.connect(_on_fighter_died.bind(fighter2))
	fighter2.died.connect(_on_fighter_died.bind(fighter1))

func _on_fighter_died(winner: Fighter) -> void:
	if _game_over:
		return
	_game_over = true
	game_over.emit(winner.character_name)
