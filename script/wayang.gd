class_name Wayang
extends CharacterBody2D

@export var character_name: String = "Unknown"
@export var max_health: int = 100;
var current_health: int
@export var move_speed: float = 1500.0
@onready var animation_player = $AnimationPlayer
@export var health_bar: CanvasLayer

const GRAVITY = 8000.0
const JUMP_FORCE = -2000.0

@export var defaults_face_right: bool

func _ready():
	current_health = max_health
	on_ready() # hook for subclasses
	turn(defaults_face_right)

# pass -> override in subclass
func on_ready():
	pass
	
func attack():
	pass

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		# print(character_name + "falling")
		velocity.y += GRAVITY * delta
	
func take_damage(amount: int):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	pass  

func get_display_name() -> String:
	return character_name

func turn(to_right):
	if to_right:
		$Skeleton2D/Hip.scale.x = -1
	else:
		$Skeleton2D/Hip.scale.x = 1

func _on_area_2d_area_entered(area: Area2D) -> void:
	print(area, " entered")


func _on_area_2d_body_entered(body: Node2D) -> void:
	print(body)
