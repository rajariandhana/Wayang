class_name HealthBar
extends Node2D

@onready var progress_bar: TextureProgressBar = $TextureProgressBar

func _ready():
	progress_bar.min_value = 0
	progress_bar.max_value = 100

func setup(maximum: int, current: int):
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = maximum
		progress_bar.value = current

func set_health(current: int):
	if progress_bar:
		progress_bar.value = current
