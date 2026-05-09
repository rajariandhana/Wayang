extends CanvasLayer

var progress_bar: TextureProgressBar

func _ready():
	progress_bar = $TextureProgressBar

func set_health(current: int, maximum: int):
	if progress_bar:
		progress_bar.max_value = maximum
		progress_bar.value = current
