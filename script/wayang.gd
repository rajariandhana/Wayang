class_name Wayang
extends CharacterBody2D

@export var character_name: String = "Unknown"
@export var max_health: int = 100;
var current_health: int
@export var move_speed: float = 1500.0

func _ready():
	current_health = max_health
	on_ready() # hook for subclasses

# pass -> override in subclass
func on_ready():
	pass
	
func attack():
	pass 
	
func take_damage(amount: int):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	pass  

func get_display_name() -> String:
	return character_name
	
