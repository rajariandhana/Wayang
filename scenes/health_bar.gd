class_name HealthBar
extends Node2D

var progress_bar: TextureProgressBar

func _ready():
	progress_bar = $TextureProgressBar
	progress_bar.max_value = 100
	progress_bar.min_value = 0

func set_health(current: int):
	if progress_bar:
		progress_bar.value = current
