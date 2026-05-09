class_name Wayang
extends CharacterBody2D

@export var character_name: String = "Unknown"
@export var max_health: int = 100;
var current_health: int
@export var move_speed: float = 1500.0
@onready var animation_player = $AnimationPlayer
@export var health_bar: CanvasLayer

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
		

func _on_area_2d_area_entered(area: Area2D) -> void:
	print(area, " entered")


func _on_area_2d_body_entered(body: Node2D) -> void:
	print(body)
