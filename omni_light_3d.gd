extends OmniLight3D

@export var min_energy: float = 0.5   # The darkest the flame gets
@export var max_energy: float = 3.0   # The brightest the flame gets (crank this up if it's too dim)

var target_energy: float = 1.0
var target_pos: Vector3
var start_pos: Vector3
var timer: float = 0.0

func _ready():
	start_pos = position
	target_pos = start_pos
	target_energy = light_energy

func _process(delta):
	timer -= delta
	
	# Every fraction of a second, pick a new random brightness and a new micro-position
	if timer <= 0:
		target_energy = randf_range(min_energy, max_energy)
		
		# Jitters the light slightly on the X and Y axis to make the shadows dance
		var jitter_x = randf_range(-0.15, 0.15)
		var jitter_y = randf_range(-0.15, 0.15)
		target_pos = start_pos + Vector3(jitter_x, jitter_y, 0)
		
		# Reset the timer for the next "crackle" (between 0.05 and 0.15 seconds)
		timer = randf_range(0.05, 0.15)

	# Smoothly glide towards those targets incredibly fast
	light_energy = lerp(light_energy, target_energy, 15.0 * delta)
	position = lerp(position, target_pos, 15.0 * delta)
