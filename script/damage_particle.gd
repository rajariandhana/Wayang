extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play()

	sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	queue_free()