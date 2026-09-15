class_name Arena2d
extends StaticBody2D

signal game_over(winner_name: String)

@onready var fighter1: Fighter = $Fighter1
@onready var fighter2: Fighter = $Fighter2

var _game_over := false

func _ready() -> void:
	# Single source of truth for which way each puppet is facing, so directional
	# moves (lunges, forward/back attacks) commit toward the opponent instead of
	# toward a hardcoded screen side.
	_assign_facing()
	fighter1.died.connect(_on_fighter_died.bind(fighter1, fighter2))
	fighter2.died.connect(_on_fighter_died.bind(fighter2, fighter1))

func _on_fighter_died(_died_fighter: Fighter, other_fighter: Fighter) -> void:
	if _game_over:
		return
	_game_over = true
	if other_fighter.life_state == Fighter.LifeState.DEAD:
		game_over.emit("Draw")
	else:
		game_over.emit(other_fighter.character_name)

func _assign_facing() -> void:
	var direction := signf(fighter2.global_position.x - fighter1.global_position.x)
	if direction == 0.0:
		direction = 1.0
	fighter1.facing = direction
	fighter2.facing = -direction
